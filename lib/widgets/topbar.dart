import 'package:serial_host/misc/file_utilities.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/host_data_model.dart';
import '../models/parameter_table_model.dart';
import '../protocol/serial_parse.dart';
import 'message_widget.dart';

class TopBar extends StatelessWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hostDataModel = Provider.of<HostDataModel>(context, listen: false);
    final parameterTableModel =
        Provider.of<ParameterTableModel>(context, listen: false);

    final openFileMenuItem = PopupMenuItem(
        child: const Text("open file"),
        onTap: () {
          hostDataModel.openConfigFile(() {
            if (hostDataModel.configData.initialized) {
              parameterTableModel.initNumParameters(
                  hostDataModel.configData.parameter.length);
            }
            displayMessage(context, hostDataModel.userMessage);
          });
        });

    final saveFileMenuItem = PopupMenuItem(
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
        onTap: () {
          if (hostDataModel.configData.telemetry.isNotEmpty) {
            hostDataModel
                .saveFile(generateConfigFile(hostDataModel.configData));
          }
        });

    final createDataFileMenuItem = PopupMenuItem(
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
        onTap: () {
          if (hostDataModel.serial.isRunning) {
            hostDataModel.createDataFile();
          }
        });

    final parseDataMenuItem = PopupMenuItem(
        child: const Text("parse data"),
        onTap: () {
          hostDataModel.parseDataFile(
              true, () => displayMessage(context, hostDataModel.userMessage));
        });

    final saveByteFileMenuItem = PopupMenuItem(
      child: Row(
        children: [
          const Text("save byte file"),
          const Spacer(),
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
    );

    final createHeaderMenuItem = PopupMenuItem(
        child: const Text("create header"),
        onTap: () {
          if (hostDataModel.configData.telemetry.isNotEmpty) {
            hostDataModel
                .saveFile(generateHeaderFile(hostDataModel.configData));
          }
        });

    final programTargetMenuItem = PopupMenuItem(
        child: const Text("program target"),
        onTap: () {
      hostDataModel.initBootloader().then((_) {
        displayMessage(context, hostDataModel.userMessage);
      });
    });

    final fileMenu = Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton(
        child: const Text("File"),
        itemBuilder: (context) => <PopupMenuItem>[
          openFileMenuItem,
          saveFileMenuItem,
          createDataFileMenuItem,
        ],
      ),
    );

    final toolsMenu = Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton(
        child: const Text("Tools"),
        itemBuilder: (context) => <PopupMenuItem>[
          parseDataMenuItem,
          saveByteFileMenuItem,
          createHeaderMenuItem,
          programTargetMenuItem,
        ],
      ),
    );

    const comPortLabel = Padding(
      padding: EdgeInsets.all(8.0),
      child: Text("Port: "),
    );

    final recordButton = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Selector<HostDataModel, RecordState>(
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
      ),
    );

    final comPortInput = Padding(
      padding: const EdgeInsets.all(8.0),
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
      padding: EdgeInsets.all(8.0),
      child: Text("Baud Rate: "),
    );

    final baudRateInput = Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
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
      padding: EdgeInsets.all(8.0),
      child: Text("Tx Period: "),
    );

    final periodTextController = TextEditingController(
        text: hostDataModel.configData.commPeriod.toString());

    final periodInput = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Selector<HostDataModel, int>(
        selector: (_, selectorModel) => selectorModel.configData.commPeriod,
        builder: (context, commPeriod, child) {
          periodTextController.text = commPeriod.toString();
          return SizedBox(
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
      padding: EdgeInsets.all(8.0),
      child: Text("Network ID: "),
    );

    final networkTextController =
    TextEditingController(text: hostDataModel.networkId.toString());

    final networkIdInput = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Selector<HostDataModel, int>(
        selector: (_, selectorModel) => selectorModel.networkId,
        builder: (context, networkId, child) {
          networkTextController.text = networkId.toString();
          return SizedBox(
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
      padding: const EdgeInsets.all(8.0),
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

    return Row(
      children: [
        fileMenu,
        toolsMenu,
        recordButton,
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
