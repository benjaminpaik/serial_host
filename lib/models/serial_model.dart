import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'dart:async';
import 'package:serial_host/definitions.dart';
import 'package:serial_host/protocol/serial_parse.dart';
import 'package:serial_host/protocol/serial_protocol.dart';

import '../misc/config_data.dart';
import '../misc/parameter.dart';

class SerialModel extends ChangeNotifier {

  String _userMessage = "";
  final SerialApi _serial;
  final ConfigData _configData;
  String? _comSelection;
  int _command = 0;

  SerialModel(this._serial, this._configData);

  Future<bool> serialConnect() async {
    bool connected = false;
    if (!_serial.isRunning) {
      if (_comSelection != null) {
        _serial.commPeriod = _configData.commPeriod;
        await _serial.openPort(_comSelection!, _configData.baudRate, 0, 8, 1);
        connected = await getParametersUserSequence();
        if (connected) {
          for (var parameter in _configData.parameter) {
            parameter.connectedValue = parameter.currentValue;
          }
          _userMessage = Message.info.connected;
        }
      }
    } else {
      _serial.closePort();
      _userMessage = Message.info.disconnected;
    }
    notifyListeners();
    return connected;
  }

  bool get isRunning {
    return _serial.isRunning;
  }

  int get command {
    return _command;
  }

  set command(int value) {
    _command = value;
    SerialParse.setData32(_serial, _command, SerialParse.commandValueIndex);
    _serial.sendPacket();
    notifyListeners();
  }

  int get commandMax {
    return _configData.commandMax;
  }

  int get commandMin {
    return _configData.commandMin;
  }

  int get mode {
    return SerialParse.getCommandMode(_serial);
  }

  set mode(int value) {
    SerialParse.setCommandMode(_serial, value, SerialParse.packetMin);
    _serial.sendPacket();
  }

  List<String> get comPorts {
    return SerialPort.availablePorts;
  }

  String? get comSelection {
    return _comSelection;
  }

  set comSelection(String? selection) {
    _comSelection = selection;
    notifyListeners();
  }

  int get deviceId {
    return _configData.deviceId;
  }

  bool setDeviceId(int? id) {
    _userMessage = "";
    if (id != null) {
      try {
        _configData.deviceId = id;
        SerialParse.setDeviceId(_serial, _configData.deviceId);
        _serial.sendPacket();
        notifyListeners();
        return true;
      } catch (e) {
        _userMessage = Message.error.deviceIdRange;
      }
    } else {
      _userMessage = Message.error.deviceIdText;
    }
    return false;
  }

  int get baudRate {
    return _configData.baudRate;
  }

  set baudRate(int value) {
    _configData.baudRate = value;
    notifyListeners();
  }

  set commPeriod(int value) {
    if (value > 0) {
      _configData.commPeriod = value;
      _serial.commPeriod = _configData.commPeriod;
      notifyListeners();
    }
  }

  int get commPeriod {
    return _configData.commPeriod;
  }

  void updateFromConfig() {
    notifyListeners();
  }

  Future<bool> getParametersUserSequence() async {
    _userMessage = "";
    bool success = false;
    await getNumParameters().then((numDeviceParameters) async {
      if (numDeviceParameters >= 0) {
        if (_configData.parameter.isNotEmpty &&
            numDeviceParameters != _configData.parameter.length) {
          _userMessage = Message.error.parameterLengthMatch;
        } else {
          if (_configData.parameter.isEmpty) {
            for (int i = 0; i < numDeviceParameters; i++) {
              _configData.parameter.add(Parameter());
            }
          }

          await getParameters().then((getParameterSuccess) {
            if (getParameterSuccess) {
              for (var parameter in _configData.parameter) {
                parameter.currentValue = parameter.deviceValue;
              }
              _userMessage = Message.info.parameterGet;
              success = true;
            } else {
              _userMessage = Message.error.parameterGet;
            }
          });
        }
      } else {
        _userMessage = Message.error.parameterNum;
      }
    });
    return success;
  }

  Future<int> getNumParameters() async {
    int deviceParameterLength = -1;
    if (_serial.isRunning) {
      SerialParse.setCommandMode(
          _serial, SerialParse.readParameters, SerialParse.packetMin);
      SerialParse.setData32(_serial, 0, SerialParse.parameterTableIndex);
      _serial.sendPacket();
      _serial.startWatchdog(parameterTimeout);

      while (!_serial.watchdogTripped) {
        if ((SerialParse.getCommandMode(_serial) == SerialParse.readParameters &&
            SerialParse.getData32(_serial, SerialParse.parameterTableIndex) ==
                0)) {
          deviceParameterLength = SerialParse.getData32(_serial, 1);
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      SerialParse.setCommandMode(
          _serial, SerialParse.nullMode, SerialParse.packetMin);
      _serial.sendPacket();
    }
    return deviceParameterLength;
  }

  Future<bool> getParameters() async {
    bool success = false;
    if (_serial.isRunning) {
      final parameters = _configData.parameter;
      final returnBuffer = List<int>.filled(parameters.length, 0);
      int parametersPerRx = SerialParse.totalStates - 1;
      int totalTransfers = (returnBuffer.length / parametersPerRx).ceil();

      for (int transfer = 0; transfer < totalTransfers; transfer++) {
        SerialParse.setCommandMode(
            _serial, SerialParse.readParameters, SerialParse.packetMin);
        SerialParse.setData32(
            _serial, transfer, SerialParse.parameterTableIndex);
        _serial.sendPacket();
        _serial.startWatchdog(parameterTimeout);

        while (!_serial.watchdogTripped) {
          if ((SerialParse.getCommandMode(_serial) ==
              SerialParse.readParameters &&
              SerialParse.getData32(_serial, SerialParse.parameterTableIndex) ==
                  transfer)) {
            for (int i = 0; i < parametersPerRx; i++) {
              int parameterIndex = i + (transfer * parametersPerRx);
              if (parameterIndex >= parameters.length) {
                success = true;
                break;
              }
              parameters[parameterIndex].deviceValue =
                  SerialParse.getData32(_serial, i + 1);
            }
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
      SerialParse.setCommandMode(
          _serial, SerialParse.nullMode, SerialParse.packetMin);
      _serial.sendPacket();
    }
    return success;
  }

  Future<bool> sendParameters() async {
    bool success = false;
    _userMessage = Message.error.parameterWrite;
    if (_serial.isRunning) {
      final parameters = _configData.parameter;
      int parametersPerTx = SerialParse.totalStates - 1;
      int totalTransfers = (parameters.length / parametersPerTx).ceil();

      for (int transfer = 0; transfer < totalTransfers; transfer++) {
        SerialParse.setCommandMode(
            _serial, SerialParse.writeParameters, SerialParse.packetMax);
        SerialParse.setData32(
            _serial, transfer, SerialParse.parameterTableIndex);
        for (int i = 0; i < parametersPerTx; i++) {
          int parameterIndex = i + (transfer * parametersPerTx);
          if (parameterIndex >= parameters.length) break;
          SerialParse.setData32(_serial,
              parameters[parameterIndex].currentValue?.toInt() ?? 0, i + 1);
        }

        _serial.sendPacket();
        _serial.startWatchdog(parameterTimeout);
        while (!_serial.watchdogTripped) {
          if ((SerialParse.getCommandMode(_serial) ==
              SerialParse.writeParameters &&
              SerialParse.getData32(_serial, SerialParse.parameterTableIndex) ==
                  transfer)) break;
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      await getParameters().then((parametersRetrieved) {
        if (parametersRetrieved) {
          final parameterMismatch = parameters
              .where((e) => e.deviceValue != e.currentValue)
              .map((e) => e.name);
          if (parameterMismatch.isEmpty) {
            _userMessage = Message.info.parameterWrite;
            success = true;
          } else {
            _userMessage = Message.error.parameterUpdate(parameterMismatch);
          }
        }
      });
    }
    return success;
  }

  Future<bool> flashParameters() async {
    _userMessage = "";
    bool success = false, nullComplete = false;
    if (_serial.isRunning) {
      SerialParse.setCommandMode(
          _serial, SerialParse.nullMode, SerialParse.packetMin);
      _serial.sendPacket();
      _serial.startWatchdog(parameterTimeout);

      while (!_serial.watchdogTripped) {
        if (SerialParse.getCommandMode(_serial) == SerialParse.nullMode) {
          nullComplete = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      if (nullComplete) {
        SerialParse.setCommandMode(
            _serial, SerialParse.flashParameters, SerialParse.packetMin);
        _serial.sendPacket();
        _serial.startWatchdog(parameterTimeout);

        while (!_serial.watchdogTripped) {
          if (SerialParse.getCommandMode(_serial) ==
              SerialParse.flashParameters) {
            _userMessage = Message.info.parameterFlash;
            success = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (!nullComplete || !success) {
        _userMessage = Message.error.parameterFlash;
      }

      SerialParse.setCommandMode(
          _serial, SerialParse.nullMode, SerialParse.packetMin);
      _serial.sendPacket();
    }
    return success;
  }

  Future<bool> initBootloader() async {
    _userMessage = "";
    bool success = false, nullComplete = false;
    if (_serial.isRunning) {
      SerialParse.setCommandMode(
          _serial, SerialParse.nullMode, SerialParse.packetMin);
      _serial.sendPacket();
      _serial.startWatchdog(parameterTimeout);

      while (!_serial.watchdogTripped) {
        if (SerialParse.getCommandMode(_serial) == SerialParse.nullMode) {
          nullComplete = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      if (nullComplete) {
        SerialParse.setCommandMode(
            _serial, SerialParse.reprogramBootMode, SerialParse.packetMin);
        _serial.sendPacket();
        _serial.startWatchdog(parameterTimeout);

        while (!_serial.watchdogTripped) {
          if (SerialParse.getCommandMode(_serial) ==
              SerialParse.reprogramBootMode) {
            _userMessage = Message.info.bootloader;
            success = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (!nullComplete || !success) {
        _userMessage = Message.error.bootloader;
      }
    }
    return success;
  }

  String get userMessage {
    return _userMessage;
  }

}
