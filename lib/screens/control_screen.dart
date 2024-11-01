import 'package:serial_host/models/serial_model.dart';
import 'package:serial_host/models/telemetry_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../definitions.dart';
import '../widgets/oscilloscope_widget.dart';

class ControlPage extends StatelessWidget {
  static const String title = 'Control';
  static Icon icon = const Icon(Icons.code);

  const ControlPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 20, child: OscilloscopePlots()),
        const Spacer(),
        const Expanded(flex: 3, child: CmdInput()),
        const Spacer(),
        Expanded(flex: 3, child: CmdButtons()),
        const Spacer(),
      ],
    );
  }
}

class OscilloscopePlots extends StatelessWidget {
  final valueScrollController = ScrollController();

  OscilloscopePlots({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataHeaders =
    ["name: ", "value: "].map((e) => DataColumn(label: Text(e))).toList();
    final telemetryModel = Provider.of<TelemetryModel>(context, listen: false);

    final oscilloscope = Selector<TelemetryModel, int>(
      selector: (_, selectorModel) => selectorModel.graphUpdateCount,
      builder: (context, _, child) {
        return Oscilloscope(key: key, plotData: telemetryModel.plotData);
      },
    );

    final valueList = Selector<TelemetryModel, int>(
      selector: (_, selectorModel) => selectorModel.textUpdateCount,
      builder: (context, _, child) {
        final telemetry = telemetryModel.telemetry;
        if (telemetryModel.plotData.updatePlots) {
          for (var element in telemetry) {
            element.updateScaledValue();
          }
        }
        final dataRows = List<DataRow>.generate(telemetry.length, (index) {
          return DataRow(
            color: WidgetStateProperty.all(telemetry[index].color),
            selected: telemetry[index].display,
            onSelectChanged: (selected) {
              telemetry[index].display = selected ?? false;
              if (telemetry[index].display) {
                telemetryModel.selectedState = telemetry[index].name;
              } else {
                // set the selected oscilloscope state to the first state displayed
                telemetryModel.selectedState = telemetry
                    .firstWhere((element) => element.display,
                    orElse: () => telemetry.first)
                    .name;
              }
              telemetryModel.updateDisplaySelection();
            },
            cells: [
              DataCell(SizedBox(
                width: 100,
                child: Text(telemetry[index].name),
              )),
              DataCell(Text(telemetry[index].scaledValue)),
            ],
          );
        });

        return SingleChildScrollView(
          controller: valueScrollController,
          scrollDirection: Axis.vertical,
          child: DataTable(
            columnSpacing: 0,
            columns: dataHeaders,
            rows: dataRows,
          ),
        );
      },
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 15,
          child: oscilloscope,
        ),
        Expanded(
          flex: 5,
          child: valueList,
        ),
      ],
    );
  }
}

class CmdInput extends StatelessWidget {
  const CmdInput({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serialModel = Provider.of<SerialModel>(context, listen: false);
    final TextEditingController cmdTextController =
    TextEditingController(text: 0.toString());

    final cmdScrollBar = Selector<SerialModel, int>(
        selector: (_, model) => model.command,
        builder: (context, _, child) {
          return Slider(
              onChanged: (value) {
                serialModel.command = value.round();
              },
              onChangeEnd: (value) {
                cmdTextController.text = value.round().toString();
              },
              min: serialModel.commandMin.toDouble(),
              max: serialModel.commandMax.toDouble(),
              divisions: (serialModel.commandMax - serialModel.commandMin),
              value: serialModel.command.toDouble(),
              label: serialModel.command.toString());
        });

    final cmdTextField = Row(
      children: [
        const Spacer(flex: 3),
        Expanded(
          child: Selector<SerialModel, int>(
            selector: (_, model) => model.command,
            builder: (context, _, child) {
              return TextField(
                controller: cmdTextController,
                onSubmitted: (text) {
                  int? value = int.tryParse(text);
                  if (value != null) serialModel.command = value;
                },
              );
            },
          ),
        ),
        const Spacer(flex: 3),
      ],
    );

    return Column(
      children: [
        Expanded(
            flex: 1,
            child: cmdScrollBar
        ),
        Expanded(
          flex: 3,
          child: cmdTextField,
        ),
      ],
    );
  }
}

class CmdButtons extends StatelessWidget {
  final cmdTextController = TextEditingController();
  final buttonScrollController = ScrollController();

  CmdButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serialModel = Provider.of<SerialModel>(context, listen: false);

    final modeButtonList = Selector<TelemetryModel, List<String>>(
      selector: (_, selectorModel) => selectorModel.modes,
      builder: (context, modes, child) {
        return GridView.extent(
          childAspectRatio: buttonWidth / buttonHeight,
          maxCrossAxisExtent: buttonWidth,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 25.0),
          mainAxisSpacing: 25,
          crossAxisSpacing: 25,
          children: List.generate(
              modes.length,
                  (index) => ElevatedButton(
                child: Center(child: Text(modes[index])),
                onPressed: () {
                  serialModel.mode = index + 1;
                },
              )),
        );
      },
    );

    return Selector<SerialModel, int>(
      selector: (_, serialModel) => serialModel.command,
      builder: (context, hostCommand, child) {
        return SingleChildScrollView(
          controller: buttonScrollController,
          scrollDirection: Axis.vertical,
          child: modeButtonList,
        );
      },
    );
  }
}
