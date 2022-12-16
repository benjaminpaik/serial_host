
import 'package:serial_host/misc/parameter.dart';
import 'package:serial_host/misc/telemetry.dart';
import 'package:serial_host/protocol/serial_parse.dart';

enum ConfigDataKeys {
  baudRate,
  commPeriod,
  networkId,
  commandMax,
  commandMin,
  modes,
  telemetry,
  status,
  parameter,
}

class ConfigData {
  bool initialized = false;
  int _baudRate = SerialParse.defaultBaudRate,
      _commPeriod = SerialParse.defaultPeriod,
      _networkId = SerialParse.networkIdMin,
      _commandMax = 1000,
      _commandMin = -1000;
  List<String> modes = List.empty(growable: true);
  List<Telemetry> telemetry = List.empty(growable: true);
  BitStatus status = BitStatus();
  List<Parameter> parameter = List.empty(growable: true);

  set baudRate(int value) {
    if (SerialParse.validBaudRates.contains(value)) {
      _baudRate = value;
    } else {
      throw FormatException;
    }
  }

  int get baudRate {
    return _baudRate;
  }

  set commPeriod(int value) {
    if (value >= SerialParse.defaultPeriod) {
      _commPeriod = value;
    } else {
      throw FormatException;
    }
  }

  int get commPeriod {
    return _commPeriod;
  }

  set networkId(int id) {
    if (id >= SerialParse.networkIdMin && id <= SerialParse.networkIdMax) {
      _networkId = id;
    } else {
      throw FormatException;
    }
  }

  int get networkId {
    return _networkId;
  }

  void setRange(int max, int min) {
    if (max > min) {
      _commandMax = max;
      _commandMin = min;
    } else {
      throw FormatException;
    }
  }

  int get commandMax {
    return _commandMax;
  }

  int get commandMin {
    return _commandMin;
  }

  Map<ConfigDataKeys, dynamic> toMap() {
    return {
      ConfigDataKeys.baudRate: _baudRate,
      ConfigDataKeys.commPeriod: _commPeriod,
      ConfigDataKeys.networkId: _networkId,
      ConfigDataKeys.commandMax: _commandMax,
      ConfigDataKeys.commandMin: _commandMin,
      ConfigDataKeys.modes: modes,
      ConfigDataKeys.telemetry: telemetry,
      ConfigDataKeys.status: status,
      ConfigDataKeys.parameter: parameter,
    };
  }

  static ConfigData fromMap(Map<ConfigDataKeys, dynamic> map) {
    return ConfigData()
      ..baudRate = map[ConfigDataKeys.baudRate]
      ..commPeriod = map[ConfigDataKeys.commPeriod]

      ..networkId = map[ConfigDataKeys.networkId]
      .._commandMax = map[ConfigDataKeys.commandMax]
      .._commandMin = map[ConfigDataKeys.commandMin]
      ..modes = map[ConfigDataKeys.modes]
      ..telemetry = map[ConfigDataKeys.telemetry]
      ..status = map[ConfigDataKeys.status]
      ..parameter = map[ConfigDataKeys.parameter];
  }

}
