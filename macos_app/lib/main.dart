import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/main_view.dart';
import 'providers/providers.dart';
import 'utils/system_tray_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final pubspec = Pubspec.parse(await rootBundle.loadString('pubspec.yaml'));
  final version = pubspec.version;
  debugPrint('version from pubspec.yaml: $version');
  sharedPreferences.setString('appVersion', version.toString());
  // Create ProviderContainer to access providers before runApp
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ],
  );

  // Initialize system tray
  await container.read(systemTrayManagerProvider).initSystemTray();

  runApp(
    ProviderScope(
      parent: container,
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Later',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MainView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
