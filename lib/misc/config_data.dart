import 'package:serial_host/misc/parameter.dart';
import 'package:serial_host/misc/telemetry.dart';

import '../protocol/serial_parse.dart';

enum ConfigKeys {
  serial,
  command,
  telemetry,
  status,
  parameters,
}

enum ConfigSerialKeys {
  baud,
  period,
  device,
}

enum ConfigCommandKeys {
  max,
  min,
  modes,
}

class ConfigData {
  int _baudRate = SerialParse.defaultBaudRate,
      _commPeriod = SerialParse.defaultPeriod,
      _deviceId = SerialParse.deviceIdMin,
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

  set deviceId(int id) {
    if (id >= SerialParse.deviceIdMin && id <= SerialParse.deviceIdMax) {
      _deviceId = id;
    } else {
      throw FormatException;
    }
  }

  int get deviceId {
    return _deviceId;
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

  Map<String, dynamic> toMap() {
    final serialMap = {
      ConfigSerialKeys.baud: baudRate,
      ConfigSerialKeys.period: commPeriod,
      ConfigSerialKeys.device: _deviceId,
    };

    final commandMap = {
      ConfigCommandKeys.max.name: commandMax,
      ConfigCommandKeys.min.name: commandMin,
      ConfigCommandKeys.modes.name: modes,
    };

    final telemetryList = telemetry.map((e) {
      return {
        TelemetryKeys.name.name: e.name,
        TelemetryKeys.max.name: e.max,
        TelemetryKeys.min.name: e.min,
        TelemetryKeys.type.name: e.type,
        TelemetryKeys.scale.name: e.scale,
        TelemetryKeys.color.name: e.color,
        TelemetryKeys.display.name: e.display,
      };
    });

    final parameterList = parameter.map((e) => e.toMap());

    return {
      ConfigKeys.serial.name: serialMap,
      ConfigKeys.command.name: commandMap,
      ConfigKeys.telemetry.name: telemetryList,
      ConfigKeys.status.name: status.toMap(),
      ConfigKeys.parameters.name: parameterList,
    };
  }

  void updateFromNewConfig(ConfigData newConfig) {
    _baudRate = newConfig.baudRate;
    _commPeriod = newConfig.commPeriod;
    _deviceId = newConfig.deviceId;
    _commandMax = newConfig.commandMax;
    _commandMin = newConfig.commandMin;
    modes = newConfig.modes;
    telemetry = newConfig.telemetry;
    status = newConfig.status;

    final oldParameters = parameter;
    parameter = newConfig.parameter;

    if (parameter.isNotEmpty && (parameter.length == oldParameters.length)) {
      for (int i = 0; i < parameter.length; i++) {
        parameter[i].deviceValue = oldParameters[i].deviceValue;
        parameter[i].connectedValue = oldParameters[i].connectedValue;
      }
    }
  }

  static ConfigData fromMap(Map configMap) {
    final configData = ConfigData();

    // parse serial settings
    var serialMap = configMap[ConfigKeys.serial.name];
    try {
      serialMap = serialMap as Map;
    } catch (e) {
      throw const FormatException("invalid serial settings");
    }

    try {
      final baudRate = serialMap[ConfigSerialKeys.baud.name] as int;
      configData.baudRate = baudRate;
    } catch (e) {
      throw const FormatException("invalid baud rate");
    }

    try {
      final commPeriod = serialMap[ConfigSerialKeys.period.name] as int;
      configData.commPeriod = commPeriod;
    } catch (e) {
      throw const FormatException("invalid period");
    }

    try {
      final deviceId = serialMap[ConfigSerialKeys.device.name] as int;
      configData.deviceId = deviceId;
    } catch (e) {
      throw const FormatException("invalid device ID");
    }

    // parse command settings
    var commandMap = configMap[ConfigKeys.command.name];
    try {
      commandMap = commandMap as Map;
    } catch (e) {
      throw const FormatException("invalid command settings");
    }

    try {
      final commandMax = commandMap[ConfigCommandKeys.max.name] as int;
      final commandMin = commandMap[ConfigCommandKeys.min.name] as int;
      configData.setRange(commandMax, commandMin);
    } catch (e) {
      throw const FormatException("invalid command range");
    }

    try {
      configData.modes =
          List<String>.from(commandMap[ConfigCommandKeys.modes.name]);
    } catch (e) {
      throw const FormatException("invalid command buttons");
    }

    // parse telemetry settings
    final telemetryStringEnumMap = Map<String, TelemetryKeys>.fromEntries(
        TelemetryKeys.values.map((e) => MapEntry(e.name, e)));
    var telemetryList = <Map>[];
    try {
      telemetryList = List<Map>.from(configMap[ConfigKeys.telemetry.name]);
    } catch (e) {
      throw const FormatException("invalid telemetry settings");
    }

    for (int i = 0; i < telemetryList.length; i++) {
      try {
        var telemetryMap = telemetryList[i]
            .map((k, v) => MapEntry(telemetryStringEnumMap[k]!, v));
        final telemetryValue = Telemetry.fromMap(telemetryMap);
        configData.telemetry.add(telemetryValue);
      } catch (e) {
        throw FormatException("invalid telemetry at index $i");
      }
    }

    // parse status settings
    var statusMap = <String, dynamic>{};
    try {
      statusMap = Map<String, dynamic>.from(configMap[ConfigKeys.status.name]);
    } catch (e) {
      throw const FormatException("invalid status settings");
    }
    configData.status = BitStatus.fromMap(statusMap);

    final parameterStringEnumMap = Map<String, ParameterKeys>.fromEntries(
        ParameterKeys.values.map((e) => MapEntry(e.name, e)));
    // parse parameter settings
    var parameterList = <Map>[];
    try {
      parameterList = List<Map>.from(configMap[ConfigKeys.parameters.name]);
    } catch (e) {
      throw const FormatException("invalid parameter settings");
    }

    for (int i = 0; i < parameterList.length; i++) {
      try {
        if (parameterList[i].keys.first.runtimeType == String) {
          final parameterMap = parameterList[i]
              .map((k, v) => MapEntry(parameterStringEnumMap[k]!, v));
          configData.parameter.add(Parameter.fromConfigMap(parameterMap));
        } else {
          configData.parameter.add(Parameter.fromConfigMap(parameterList[i]));
        }
      } catch (e) {
        throw FormatException("invalid parameter at index $i - type mismatch");
      }
    }
    return configData;
  }
}
