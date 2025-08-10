import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart'
    hide VoidCallbackIntent, VoidCallbackAction;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:uni_links/uni_links.dart';
import 'package:window_manager/window_manager.dart';

import 'services/database_service.dart';
import 'utils/platform_menu.dart';

import 'models/models.dart';
import 'pages/main_view.dart';
import 'pages/settings_page.dart';
import 'providers/providers.dart';
import 'utils/dialog_service.dart';
import 'utils/intent.dart';
import 'utils/keyboard_shortcuts.dart';
import 'utils/system_tray_manager.dart';

/// This method initializes macos_window_utils and styles
///  window.
Future<void> _configureMacosWindowUtils() async {
  const config = MacosWindowUtilsConfig(
    toolbarStyle: NSWindowToolbarStyle.unified,
  );
  await config.apply();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureMacosWindowUtils();

  // Initialize local notifier
  final localNotifier = LocalNotifier.instance;
  await localNotifier.setup(appName: 'Later');

  // Initialize database service
  final databaseService = DatabaseService();
  await databaseService.initialize();

  final pubspec = Pubspec.parse(await rootBundle.loadString('pubspec.yaml'));
  final version = pubspec.version;
  debugPrint('version from pubspec.yaml: $version');

  // Get initial data folder path from settings or set a default
  String initialDataFolderPath = '';
  // Settings are not stored in the database currently, so this will be empty

  // Set or validate the data folder path
  try {
    // Get the application documents directory as our default location
    final appDocDir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(appDocDir.path, 'Later');

    // If no data folder path is set, use the default
    if (initialDataFolderPath.isEmpty) {
      initialDataFolderPath = defaultPath;
    }

    // Ensure the directory exists
    final directory = Directory(initialDataFolderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    debugPrint('Data folder path: $initialDataFolderPath');
  } catch (e) {
    debugPrint('Error setting data folder path: $e');
    // Fallback to a temporary directory if necessary
    final tempDir = await getTemporaryDirectory();
    initialDataFolderPath = path.join(tempDir.path, 'Later');
    final directory = Directory(initialDataFolderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    debugPrint('Using temporary data folder path: $initialDataFolderPath');
  }

  // Must be called before runApp
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    minimumSize: Size(800, 600),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
        dataFolderPathProvider.overrideWithValue(initialDataFolderPath),
      ],
      child: const LaterApp(),
    ),
  );
}

class LaterApp extends ConsumerWidget {
  const LaterApp({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifier);

    MacosThemeData lightTheme;
    MacosThemeData darkTheme;

    // Apply custom theme if selected
    if (settings.selectedTheme != null) {
      final customTheme = settings.selectedTheme;
      if (customTheme.isDark) {
        // If the selected theme is dark, use it as dark theme and default light theme
        darkTheme = customTheme.toMacosThemeData();
        lightTheme = MacosThemeData().copyWith(
          primaryColor: Colors.grey.shade800,
          iconButtonTheme: MacosIconButtonThemeData(
            disabledColor: Colors.grey.shade800,
          ),
        );
      } else {
        // If the selected theme is light, use it as light theme and default dark theme
        lightTheme = customTheme.toMacosThemeData();
        darkTheme = MacosThemeData.dark().copyWith(
          primaryColor: Colors.white,
          iconButtonTheme: const MacosIconButtonThemeData(
            disabledColor: Colors.white,
          ),
        );
      }
    } else {
      // Use default themes
      lightTheme = MacosThemeData().copyWith(
        primaryColor: Colors.grey.shade800,
        iconButtonTheme: MacosIconButtonThemeData(
          disabledColor: Colors.grey.shade800,
        ),
      );
      darkTheme = MacosThemeData.dark().copyWith(
        primaryColor: Colors.white,
        iconButtonTheme: const MacosIconButtonThemeData(
          disabledColor: Colors.white,
        ),
      );
    }

    return PlatformMenuBar(
      menus: LaterPlatformMenu.build(context, ref).menus,
      child: MacosApp(
        routes: {
          '/settings': (context) => const SettingsPage(),
        },
        debugShowCheckedModeBanner: false,
        navigatorKey: DialogService.navigatorKey,
        title: 'Later',
        theme: lightTheme,
        darkTheme: darkTheme,
        color: Colors.transparent,
        themeMode: settings.themeMode,
        home: Builder(
          builder: (context) {
            // Create shortcuts map
            final shortcuts =
                KeyboardShortcuts.getApplicationShortcuts(context, ref);

            return Shortcuts(
              shortcuts: Map.fromEntries(
                shortcuts.keys.map((key) =>
                    MapEntry(key, VoidCallbackIntent(shortcuts[key]!))),
              ),
              child: Actions(
                actions: <Type, Action<Intent>>{
                  VoidCallbackIntent: VoidCallbackAction(),
                },
                child: Focus(
                  autofocus: true,
                  child: const MainView(),
                ),
              ),
            );
          },
        ),
        // No need for debugShowCheckedModeBanner here
      ),
    );
  }
}
