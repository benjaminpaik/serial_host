import 'package:flutter/services.dart';
import 'package:serial_host/misc/file_utilities.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/host_data_model.dart';
import '../models/parameter_table_model.dart';
import '../protocol/serial_parse.dart';
import 'message_widget.dart';

const _verticalPadding = 8.0;
const _horizontalPadding = 8.0;

class TopBar extends StatelessWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hostDataModel = Provider.of<HostDataModel>(context, listen: false);
    final parameterTableModel =
        Provider.of<ParameterTableModel>(context, listen: false);

    final openFileMenuItem = MenuItemButton(
        onPressed: () {
          hostDataModel.openConfigFile(() {
            if (hostDataModel.configData.initialized) {
              parameterTableModel
                  .initNumParameters(hostDataModel.configData.parameter.length);
            }
            displayMessage(context, hostDataModel.userMessage);
          });
        },
        shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
        child: const Text("open file"));

    final saveFileMenuItem = MenuItemButton(
      onPressed: () {
        if (hostDataModel.configData.telemetry.isNotEmpty) {
          hostDataModel.saveFile(generateConfigFile(hostDataModel.configData));
        }
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
      child: Selector<HostDataModel, bool>(
        selector: (_, selectorModel) =>
            selectorModel.configData.telemetry.isNotEmpty,
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
        if (hostDataModel.serial.isRunning) {
          hostDataModel.createDataFile();
        }
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyD, control: true),
      child: Selector<HostDataModel, bool>(
        selector: (_, selectorModel) => selectorModel.serial.isRunning,
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
          hostDataModel.parseDataFile(
              true, () => displayMessage(context, hostDataModel.userMessage));
        });

    final saveByteFileMenuItem = MenuItemButton(
      child: Row(
        children: [
          const Text("save byte file"),
          Selector<HostDataModel, bool>(
            selector: (_, selectorModel) => selectorModel.saveByteFile,
            builder: (context, saveByteFile, child) {
              return Checkbox(
                  value: hostDataModel.saveByteFile,
                  onChanged: (bool? value) {
                    hostDataModel.saveByteFile = value ?? false;
                  });
            },
          ),
        ],
      ),
      onPressed: () {},
    );

    final createHeaderMenuItem = MenuItemButton(
      onPressed: () {
        if (hostDataModel.configData.telemetry.isNotEmpty) {
          hostDataModel.saveFile(generateHeaderFile(hostDataModel.configData));
        }
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyH, control: true),
      child: Selector<HostDataModel, bool>(
        selector: (_, selectorModel) =>
            selectorModel.configData.telemetry.isNotEmpty,
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
        hostDataModel.initBootloader().then((_) {
          displayMessage(context, hostDataModel.userMessage);
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

    final recordButton = Selector<HostDataModel, RecordState>(
      selector: (_, selectorModel) => selectorModel.serial.recordState,
      builder: (context, recordState, child) {
        return IconButton(
            onPressed: () {
              hostDataModel.recordButtonEvent(() {
                displayMessage(context, hostDataModel.userMessage);
              });
            },
            icon: recordState.icon);
      },
    );

    final comPortInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<HostDataModel, String?>(
        selector: (_, selectorModel) => selectorModel.comSelection,
        builder: (context, _, child) {
          return DropdownButton(
            value: hostDataModel.comSelection,
            items: hostDataModel.comPorts
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (String? comSelection) {
              hostDataModel.comSelection = comSelection;
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
      child: Selector<HostDataModel, int>(
        selector: (_, selectorModel) => selectorModel.baudRate,
        builder: (context, _, child) {
          return DropdownButton(
            value: hostDataModel.baudRate,
            items: SerialParse.validBaudRates
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.toString())))
                .toList(),
            onChanged: (int? baudRate) {
              if (baudRate != null) {
                hostDataModel.baudRate = baudRate;
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
        text: hostDataModel.configData.commPeriod.toString());

    final periodInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<HostDataModel, int>(
        selector: (_, selectorModel) => selectorModel.configData.commPeriod,
        builder: (context, commPeriod, child) {
          periodTextController.text = commPeriod.toString();
          return SizedBox(
            height: 20.0,
            width: 25.0,
            child: TextField(
              controller: periodTextController,
              onSubmitted: (text) {
                int? value = int.tryParse(text);
                if (value != null) {
                  hostDataModel.commPeriod = value;
                  periodTextController.text =
                      hostDataModel.configData.commPeriod.toString();
                }
              },
            ),
          );
        },
      ),
    );

    const networkIdLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Network ID: "),
    );

    final networkTextController =
        TextEditingController(text: hostDataModel.networkId.toString());

    final networkIdInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<HostDataModel, int>(
        selector: (_, selectorModel) => selectorModel.networkId,
        builder: (context, networkId, child) {
          networkTextController.text = networkId.toString();
          return SizedBox(
            height: 20.0,
            width: 25.0,
            child: TextField(
              controller: networkTextController,
              onSubmitted: (text) {
                if (hostDataModel.setNetworkId(int.tryParse(text))) {
                  networkTextController.text =
                      hostDataModel.networkId.toString();
                }
                displayMessage(context, hostDataModel.userMessage);
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
        width: 110.0,
        child: ElevatedButton(
          child: Selector<HostDataModel, bool>(
            selector: (_, selectorModel) => selectorModel.serial.isRunning,
            builder: (context, isRunning, child) {
              return Text(isRunning ? "Disconnect" : "Connect");
            },
          ),
          onPressed: () {
            hostDataModel.serialConnect().then((success) {
              if (success) {
                parameterTableModel.updateTable();
              }
              displayMessage(context, hostDataModel.userMessage);
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
        networkIdLabel,
        networkIdInput,
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
