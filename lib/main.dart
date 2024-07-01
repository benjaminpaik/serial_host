import 'package:serial_host/models/serial_model.dart';
import 'package:serial_host/protocol/serial_protocol.dart';
import 'package:serial_host/screens/home_route.dart';
import 'package:flutter/material.dart';
import 'package:serial_host/models/telemetry_model.dart';
import 'package:serial_host/models/parameter_table_model.dart';
import 'package:provider/provider.dart';

import 'misc/config_data.dart';
import 'models/file_model.dart';
import 'models/screen_model.dart';

const homeRoute = '/';

void main() {
  runApp(const SerialHostApp());
}

class SerialHostApp extends StatelessWidget {
  const SerialHostApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // declare classes for dependency injection here
    final serialApi = SerialApi();
    final configData = ConfigData();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScreenModel>(
            create: (context) => ScreenModel()),
        ChangeNotifierProvider<TelemetryModel>(
            create: (context) => TelemetryModel(serialApi, configData)),
        ChangeNotifierProvider<ParameterTableModel>(
            create: (context) => ParameterTableModel(configData)),
        ChangeNotifierProvider<FileModel>(
            create: (context) => FileModel(serialApi, configData)),
        ChangeNotifierProvider<ParameterTableModel>(
            create: (context) => ParameterTableModel(configData)),
        ChangeNotifierProvider<SerialModel>(
            create: (context) => SerialModel(serialApi, configData)),
      ],
      child: MaterialApp(
        title: 'Serial Host',
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: Colors.black,
          appBarTheme: const AppBarTheme(
            color: Colors.white,
            foregroundColor: Colors.black,
          ),
          textTheme: const TextTheme(
            titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: Colors.black),
            displayLarge: TextStyle(fontSize: 25.0, fontWeight: FontWeight.normal, color: Colors.white),
            titleLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Colors.black),
            titleMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Colors.black),
          ),
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.grey),
        ),
        initialRoute: homeRoute,
        routes: {
          homeRoute: (context) => const HomeRoute(),
        },
      ),
    );
  }
}
