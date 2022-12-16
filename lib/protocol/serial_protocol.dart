import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:serial_host/misc/file_utilities.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'serial_parse.dart';

enum SerialKeys {
  commPeriod,
  portName,
  baudRate,
  parity,
  numBits,
  stopBits,
  running,
  watchdogTimeout,
  dataFile,
  recordState,
}

const _initConfigData = {
  SerialKeys.portName: "",
  SerialKeys.baudRate: SerialParse.defaultBaudRate,
  SerialKeys.parity: 1,
  SerialKeys.numBits: 8,
  SerialKeys.stopBits: 1,
  SerialKeys.commPeriod: SerialParse.defaultPeriod,
  SerialKeys.running: false,
  SerialKeys.dataFile: "",
  SerialKeys.recordState: RecordState.disabled,
};

class SerialApi {
  final txBytes = Uint8List(SerialParse.txPacketMax);
  final _rxBytes = Uint8List(SerialParse.rxPacketMax);
  bool _watchdogTripped = false;
  int _checksumErrors = 0;
  Completer<SendPort> _sendPortCompleter = Completer<SendPort>();
  SendPort? _sendPort;
  final ReceivePort _receivePort;
  // clone initial config data
  final _configData = {..._initConfigData};

  SerialApi() : _receivePort = ReceivePort() {
    SerialParse.crc16Generate();
    SerialParse.crc32Generate();
    _receivePort.listen(receiveDataEvent);

    txBytes[SerialParse.headerIndex] = SerialParse.packetHeader;
    txBytes[SerialParse.bytesIndex] = SerialParse.txPacketMin;
    txBytes[SerialParse.networkIndex] = 0;
    txBytes[SerialParse.commandModeIndex] = 0;
    txBytes[SerialParse.stateIndex0] = 0xFF;
    txBytes[SerialParse.stateIndex1] = 0xFF;
    txBytes[SerialParse.timestampIndex] = 0;
    _rxBytes[SerialParse.stateIndex0] = 0xFF;
    _rxBytes[SerialParse.stateIndex1] = 0xFF;
  }

  set commPeriod(int period) {
    if (period > 0) {
      _configData[SerialKeys.commPeriod] = period;
      if (_sendPort != null) {
        _sendPort!.send({SerialKeys.commPeriod: period});
      }
    }
  }

  set dataFile(String file) {
    if (_sendPort != null) {
      _configData[SerialKeys.dataFile] = file;
      _sendPort!.send({SerialKeys.dataFile: file});
    }
  }

  String get dataFile {
    return _configData[SerialKeys.dataFile] as String;
  }

  set recordState(RecordState state) {
    if (_sendPort != null) {
      _configData[SerialKeys.recordState] = state;
      _sendPort!.send({SerialKeys.recordState: state});
    }
  }

  RecordState get recordState {
    return _configData[SerialKeys.recordState] as RecordState;
  }

  int get commPeriod {
    return _configData[SerialKeys.commPeriod] as int;
  }

  void receiveDataEvent(dynamic data) {
    if (data is List<int>) {
      for (int i = 0; i < _rxBytes.length; i++) {
        _rxBytes[i] = data[i];
      }
    } else if (data is int) {
      _checksumErrors = data;
    } else if (data is bool) {
      _watchdogTripped = data;
    } else if (data is SendPort) {
      _sendPortCompleter.complete(data);
    }
  }

  Future<void> openPort(
      String name, int baudRate, int parity, int bits, int stopBits) async {
    await Isolate.spawn(_commIsolate, _receivePort.sendPort);
    _sendPortCompleter = Completer<SendPort>();
    _sendPort = await _sendPortCompleter.future;

    if (_sendPort != null) {
      _configData[SerialKeys.portName] = name;
      _configData[SerialKeys.baudRate] = baudRate;
      _configData[SerialKeys.parity] = parity;
      _configData[SerialKeys.numBits] = bits;
      _configData[SerialKeys.stopBits] = stopBits;
      _configData[SerialKeys.running] = true;
      _sendPort!.send(_configData);
      sendPacket();
    }
  }

  void closePort() {
    if (_sendPort != null) {
      _configData[SerialKeys.running] = false;
      _sendPort!.send(_configData);
    }
  }

  void sendPacket() {
    if (_sendPort != null) {
      _sendPort!.send(txBytes);
    }
  }

  void startWatchdog(int timeout) {
    if (_sendPort != null) {
      _sendPort!.send({SerialKeys.watchdogTimeout: timeout});
    }
    _watchdogTripped = false;
  }

  bool get watchdogTripped {
    return _watchdogTripped;
  }

  int get checksumErrors {
    return _checksumErrors;
  }

  Uint8List get rxBytes {
    return _rxBytes;
  }

  bool get isRunning {
    return _configData[SerialKeys.running] as bool;
  }
}

class _SerialProtocol {
  int errorCount = 0;

  bool _watchdogTripped = false;
  int _commPeriod = SerialParse.defaultPeriod;
  int _watchdogTimeout = 0;
  int _watchdogCount = 0;
  int _serialRxIndex = 0;

  final _txBytes = Uint8List(SerialParse.txPacketMax);
  final _rxBytes = Uint8List(SerialParse.rxPacketMax);
  final _rxBuffer = Uint8List(SerialParse.rxPacketMax);
  int _bytesInRxPacket = SerialParse.rxPacketMax;
  late SerialPort _comPort;

  _SerialProtocol() {
    SerialParse.crc16Generate();
    SerialParse.crc32Generate();
    // initialize TX bytes
    _txBytes[SerialParse.headerIndex] = SerialParse.packetHeader;
    _txBytes[SerialParse.bytesIndex] = SerialParse.txPacketMin;
    _txBytes[SerialParse.networkIndex] = 0;
    _txBytes[SerialParse.commandModeIndex] = 0;
    _txBytes[SerialParse.stateIndex0] = 0xFF;
    _txBytes[SerialParse.stateIndex1] = 0xFF;
    _txBytes[SerialParse.timestampIndex] = 0;
    _rxBytes[SerialParse.stateIndex0] = 0xFF;
    _rxBytes[SerialParse.stateIndex1] = 0xFF;
  }

  void openPort(
      String name, int baudRate, int parity, int bits, int stopBits) async {
    bool success = false;
    final serialPorts = SerialPort.availablePorts;
    for (var serialPort in serialPorts) {
      if (serialPort.contains(name)) {
        _comPort = SerialPort(serialPort);

        try {
          success = _comPort.openReadWrite();
          _comPort.config = SerialPortConfig()
            ..baudRate = baudRate
            ..parity = parity
            ..bits = bits
            ..stopBits = stopBits
            ..setFlowControl(SerialPortFlowControl.none)
            ..dtr = SerialPortDtr.off;
          // comPort.flush();
        } catch (e) {
          success = false;
        }

        if (!success) {
          closePort();
        }
        break;
      }
    }
  }

  void closePort() {
    _comPort.drain();
    _comPort.flush();
    _comPort.close();
    // comPort.config.dispose();
    _comPort.dispose();
  }

  set commPeriod(int value) {
    if (value >= SerialParse.defaultPeriod) {
      _commPeriod = value;
    }
  }

  bool _rxProtocol() {
    bool validPacket = false;
    if (_comPort.bytesAvailable > 0) {
      final newRxBytes = _comPort.read(_comPort.bytesAvailable);
      for (var byte in newRxBytes) {
        _rxBuffer[_serialRxIndex] = byte & 0xFF;

        // we have reached the end of the data packet
        if (_serialRxIndex >= (_bytesInRxPacket - 1)) {
          final crcStartIndex =
              (_bytesInRxPacket & 0xFF) - SerialParse.checksumBytes;
          if ((SerialParse.crc16Checksum(_rxBuffer, crcStartIndex) ==
                  SerialParse.crc16Rx(_rxBuffer, crcStartIndex)) &&
              verifyStateData(_rxBuffer)) {
            for (int i = 0; i < _rxBytes.length; i++) {
              _rxBytes[i] = _rxBuffer[i];
            }
            validPacket = true;
          } else {
            errorCount++;
          }
          // reset the header byte and index
          _rxBuffer[SerialParse.headerIndex] = 0;
          _serialRxIndex = 0;
          // exit the loop
          break;
        }
        // if we are reading the network ID
        else if (_serialRxIndex == SerialParse.networkIndex) {
          // if the network ID is not zero and the TX/RX IDs do not match
          if (_txBytes[SerialParse.networkIndex] != 0) {
            if (_rxBuffer[SerialParse.networkIndex] !=
                _txBytes[SerialParse.networkIndex]) {
              // reset the header byte and index
              _rxBuffer[SerialParse.headerIndex] = 0;
              _serialRxIndex = 0;
              // exit the loop
              break;
            }
          }
        }
        // reading the bytes in packet index
        else if (_serialRxIndex == SerialParse.bytesIndex) {
          _bytesInRxPacket = _rxBuffer[_serialRxIndex];
          // if the bytes in the packet is out of range
          if (_bytesInRxPacket > SerialParse.rxPacketMax ||
              _bytesInRxPacket < SerialParse.rxPacketMin) {
            _bytesInRxPacket = SerialParse.rxPacketMax;
            _rxBuffer[SerialParse.headerIndex] = 0;
            _serialRxIndex = 0;
            break;
          }
        }

        // check if the header byte matches
        if (_rxBuffer[SerialParse.headerIndex] == SerialParse.packetHeader) {
          _serialRxIndex++;
        }
        // if the header does not match
        else {
          // reset the header byte and index
          _rxBuffer[SerialParse.headerIndex] = 0;
          _serialRxIndex = 0;
        }
      }
    }
    return validPacket;
  }

  void _txProtocol() {
    if (_comPort.bytesToWrite == 0) {
      int crcStartIndex;
      int crc16Checksum;

      // reset the header byte and index to prepare for the next received packet
      _rxBuffer[SerialParse.headerIndex] = 0;
      _serialRxIndex = 0;
      _txBytes[SerialParse.headerIndex] = SerialParse.packetHeader;
      _txBytes[SerialParse.timestampIndex]++;
      // determine the CRC start index
      crcStartIndex =
          _txBytes[SerialParse.bytesIndex] - SerialParse.checksumBytes;
      // calculate the checksum
      crc16Checksum = SerialParse.crc16Checksum(_txBytes, crcStartIndex);
      // load the CRC checksum
      _txBytes[crcStartIndex] = ((crc16Checksum >> 8) & 0xFF);
      _txBytes[crcStartIndex + 1] = ((crc16Checksum) & 0xFF);
      // write bytes to the serial tx buffer
      _comPort.write(Uint8List.fromList(List.generate(
          _txBytes[SerialParse.bytesIndex], (index) => _txBytes[index])));
      // comPort.write(Uint8List.fromList([0x02]));
    }
  }

  bool _watchdogCounter() {
    if (_watchdogCount < _watchdogTimeout) {
      _watchdogCount += _commPeriod;
      _watchdogTripped = false;
    }
    else if(!_watchdogTripped) {
      _watchdogTripped = true;
      return true;
    }
    return false;
  }

  void loadTxData(List<int> data) {
    for (int i = 0; i < _txBytes.length; i++) {
      _txBytes[i] = data[i];
    }
  }

  bool verifyStateData(List<int> packet) {
    // generate the state bits data
    int stateBits = (packet[SerialParse.stateIndex0] << 8) |
        (packet[SerialParse.stateIndex1]);
    // determine the expected number of bytes in the packet from the state bits
    int bytesInPacket =
        (SerialParse.bitCount(stateBits & SerialParse.stateBackMask) *
                SerialParse.bytesPerState) +
            SerialParse.requiredBytes;

    // if this is a standard data packet and the state bits match the byte count
    if (((stateBits & SerialParse.standardPacketMask) ==
            SerialParse.standardPacketMask) &&
        (bytesInPacket == packet[SerialParse.bytesIndex])) {
      // the RX data is a standard packet
      return true;
    }
    // if there is no stateBits data and we received four bytes
    else {
      return (stateBits == 0 && packet[SerialParse.bytesIndex] == 4);
    }
  }
}

Future<void> _commIsolate(SendPort sendPort) async {
  late Timer timer;
  IOSink? writer;
  _SerialProtocol serial = _SerialProtocol();
  int startTime, previousTime = 0;
  final configData = {..._initConfigData};

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((data) {
    bool openClosePort = false;
    // TX bytes input
    if (data is List<int>) {
      serial.loadTxData(data);
    } else if (data is Map) {
      // load all config data
      for (SerialKeys key in data.keys) {
        if (configData.containsKey(key)) {
          // special actions for received maps
          switch (key) {
            case (SerialKeys.running):
              openClosePort = (configData[key] != data[key]);
              break;

            case (SerialKeys.recordState):
              if (data[key] == RecordState.inProgress) {
                final dataFile = configData[SerialKeys.dataFile] as String;
                if (dataFile.isNotEmpty) {
                  writer = File(dataFile).openWrite();
                }
              } else {
                writer?.close();
              }
              break;

            default:
              break;
          }
          configData[key] = data[key];
        }
      }
      // initialize watchdog
      if (data.keys.contains(SerialKeys.watchdogTimeout)) {
        serial._watchdogCount = 0;
        serial._watchdogTimeout = data[SerialKeys.watchdogTimeout];
      }
      // update the TX rate
      serial.commPeriod = configData[SerialKeys.commPeriod] as int;
      // open and close COM port based on running key
      if (openClosePort) {
        if (configData[SerialKeys.running] == true) {
          serial.openPort(
              configData[SerialKeys.portName] as String,
              configData[SerialKeys.baudRate] as int,
              configData[SerialKeys.parity] as int,
              configData[SerialKeys.numBits] as int,
              configData[SerialKeys.stopBits] as int);
        } else {
          timer.cancel();
          serial.closePort();
          receivePort.close();
        }
      }
    }
  });

  while (configData[SerialKeys.running] == false) {
    // yield to the listener
    await Future.delayed(Duration.zero);
  }

  timer = Timer.periodic(const Duration(microseconds: 500), (timer) {
    startTime = DateTime.now().millisecondsSinceEpoch;
    if (startTime - previousTime >= serial._commPeriod) {
      serial._txProtocol();
      if(serial._watchdogCounter()) {
        sendPort.send(serial._watchdogTripped);
      }
      previousTime = startTime;
    }
    if (serial._rxProtocol()) {
      sendPort.send(serial._rxBytes);
      if (configData[SerialKeys.recordState] == RecordState.inProgress) {
        writer?.write(serial._rxBytes.toString() + newline);
      }
    }
  });
}
