import 'package:flutter/services.dart';
import 'package:serial_host/misc/file_utilities.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serial_host/models/serial_model.dart';

import '../models/file_model.dart';
import '../models/telemetry_model.dart';
import '../models/parameter_table_model.dart';
import '../protocol/serial_parse.dart';
import 'message_widget.dart';

const _verticalPadding = 8.0;
const _horizontalPadding = 8.0;

class TopBar extends StatelessWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileModel = Provider.of<FileModel>(context, listen: false);
    final telemetryModel = Provider.of<TelemetryModel>(context, listen: false);
    final parameterTableModel =
        Provider.of<ParameterTableModel>(context, listen: false);
    final serialModel = Provider.of<SerialModel>(context, listen: false);

    final openFileMenuItem = MenuItemButton(
        onPressed: () {
          fileModel.openConfigFile((bool success) {
            if (success) {
              serialModel.updateFromConfig();
              telemetryModel.updatePlotDataFromConfig();
              parameterTableModel.initRows();
            }
            displayMessage(context, fileModel.userMessage);
          });
        },
        shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
        child: const Text("open file"));

    final saveFileMenuItem = MenuItemButton(
      onPressed: () {
        fileModel.saveConfigFile();
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
      child: Selector<TelemetryModel, bool>(
        selector: (_, telemetryLoaded) => telemetryModel.telemetry.isNotEmpty,
        builder: (context, fileLoaded, child) {
          return Text(
            "save file",
            style: TextStyle(
              color: fileLoaded ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final createDataFileMenuItem = MenuItemButton(
      onPressed: () {
        if (serialModel.isRunning) {
          fileModel.createDataFile();
        }
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyD, control: true),
      child: Selector<SerialModel, bool>(
        selector: (_, model) => model.isRunning,
        builder: (context, running, child) {
          return Text(
            "create data file",
            style: TextStyle(
              color: running ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final parseDataMenuItem = MenuItemButton(
        child: const Text("parse data"),
        onPressed: () {
          fileModel.parseDataFile(
              true, () => displayMessage(context, fileModel.userMessage));
        });

    final saveByteFileMenuItem = MenuItemButton(
      child: Row(
        children: [
          const Text("save byte file"),
          Selector<TelemetryModel, bool>(
            selector: (_, selectorModel) => fileModel.saveByteFile,
            builder: (context, saveByteFile, child) {
              return Checkbox(
                  value: fileModel.saveByteFile,
                  onChanged: (bool? value) {
                    fileModel.saveByteFile = value ?? false;
                  });
            },
          ),
        ],
      ),
      onPressed: () {},
    );

    final createHeaderMenuItem = MenuItemButton(
      onPressed: () {
        fileModel.saveHeaderFile();
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyH, control: true),
      child: Selector<TelemetryModel, bool>(
        selector: (_, selectorModel) =>
        selectorModel.telemetry.isNotEmpty,
        builder: (context, fileLoaded, child) {
          return Text(
            "create header",
            style: TextStyle(
              color: fileLoaded ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final programTargetMenuItem = MenuItemButton(
      onPressed: () {
        serialModel.initBootloader().then((_) {
          displayMessage(context, serialModel.userMessage);
          serialModel.serialConnect();
        });
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyP, control: true),
      child: const Text("program target"),
    );

    final fileMenu = [
      openFileMenuItem,
      saveFileMenuItem,
      createDataFileMenuItem,
    ];

    final toolsMenu = [
      parseDataMenuItem,
      saveByteFileMenuItem,
      createHeaderMenuItem,
      programTargetMenuItem,
    ];

    const comPortLabel = Padding(
      padding: EdgeInsets.all(8.0),
      child: Text("Port: "),
    );

    final recordButton = Selector<FileModel, RecordState>(
      selector: (_, selectorModel) => fileModel.recordState,
      builder: (context, recordState, child) {
        return IconButton(
            onPressed: () {
              fileModel.recordButtonEvent(() {
                displayMessage(context, fileModel.userMessage);
              });
            },
            icon: recordState.icon);
      },
    );

    final comPortInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<SerialModel, String?>(
        selector: (_, selectorModel) => selectorModel.comSelection,
        builder: (context, _, child) {
          return DropdownButton(
            value: serialModel.comSelection,
            items: serialModel.comPorts
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (String? comSelection) {
              serialModel.comSelection = comSelection;
            },
          );
        },
      ),
    );

    const baudRateLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Baud Rate: "),
    );

    final baudRateInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<SerialModel, int>(
        selector: (_, selectorModel) => selectorModel.baudRate,
        builder: (context, _, child) {
          return DropdownButton(
            value: serialModel.baudRate,
            items: SerialParse.validBaudRates
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.toString())))
                .toList(),
            onChanged: (int? baudRate) {
              if (baudRate != null) {
                serialModel.baudRate = baudRate;
              }
            },
          );
        },
      ),
    );

    const periodLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Tx Period: "),
    );

    final periodTextController = TextEditingController(
        text: serialModel.commPeriod.toString());

    final periodInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<SerialModel, int>(
        selector: (_, selectorModel) => selectorModel.commPeriod,
        builder: (context, commPeriod, child) {
          periodTextController.text = commPeriod.toString();
          return SizedBox(
            height: 35.0,
            width: 40.0,
            child: TextField(
              controller: periodTextController,
              onSubmitted: (text) {
                int? value = int.tryParse(text);
                if (value != null) {
                  serialModel.commPeriod = value;
                  periodTextController.text =
                      serialModel.commPeriod.toString();
                }
              },
            ),
          );
        },
      ),
    );

    const deviceIdLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Device ID: "),
    );

    final deviceIdTextController =
        TextEditingController(text: serialModel.deviceId.toString());

    final deviceIdInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<SerialModel, int>(
        selector: (_, selectorModel) => selectorModel.deviceId,
        builder: (context, deviceId, child) {
          deviceIdTextController.text = deviceId.toString();
          return SizedBox(
            height: 35.0,
            width: 25.0,
            child: TextField(
              controller: deviceIdTextController,
              onSubmitted: (text) {
                if (serialModel.setDeviceId(int.tryParse(text))) {
                  deviceIdTextController.text =
                      serialModel.deviceId.toString();
                }
                displayMessage(context, serialModel.userMessage);
              },
            ),
          );
        },
      ),
    );

    final connectButton = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: SizedBox(
        width: 120.0,
        child: ElevatedButton(
          child: Selector<SerialModel, bool>(
            selector: (_, serialModel) => serialModel.isRunning,
            builder: (context, isRunning, child) {
              return Text(isRunning ? "Disconnect" : "Connect");
            },
          ),
          onPressed: () {
            serialModel.serialConnect().then((success) {
              if (success) {
                parameterTableModel.updateTable();
                telemetryModel.startPlots();
              }
              displayMessage(context, serialModel.userMessage);
            });
          },
        ),
      ),
    );

    // combine items from both menus and register shortcuts
    _initShortcuts(context, [...fileMenu, ...toolsMenu]);

    return Row(
      children: [
        MenuBar(children: [
          SubmenuButton(menuChildren: fileMenu, child: const Text('File')),
          SubmenuButton(menuChildren: toolsMenu, child: const Text('Tools')),
          recordButton,
        ]),
        const Spacer(),
        comPortLabel,
        comPortInput,
        baudRateLabel,
        baudRateInput,
        periodLabel,
        periodInput,
        deviceIdLabel,
        deviceIdInput,
        connectButton,
      ],
    );
  }
}

void _initShortcuts(BuildContext context, List<MenuItemButton> menuItems) {
  if (ShortcutRegistry.of(context).shortcuts.isEmpty) {
    final validMenuItems = menuItems
        .where((item) => item.shortcut != null && item.onPressed != null);
    final shortcutMap = {
      for (final item in validMenuItems)
        item.shortcut!: VoidCallbackIntent(item.onPressed!)
    };
    ShortcutRegistry.of(context).addAll(shortcutMap);
  }
}
