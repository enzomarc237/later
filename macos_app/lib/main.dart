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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:window_manager/window_manager.dart';

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

  final sharedPreferences = await SharedPreferences.getInstance();
  final pubspec = Pubspec.parse(await rootBundle.loadString('pubspec.yaml'));
  final version = pubspec.version;
  debugPrint('version from pubspec.yaml: $version');
  sharedPreferences.setString('appVersion', version.toString());

  // Get initial data folder path from settings or set a default
  String initialDataFolderPath = '';
  final settingsJson = sharedPreferences.getString('settings');
  if (settingsJson != null) {
    try {
      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      initialDataFolderPath = settingsMap['dataFolderPath'] as String? ?? '';
    } catch (e) {
      debugPrint('Error loading initial data folder path: $e');
    }
  }

  // Set or validate the data folder path
  try {
    // Get the application documents directory as our default location
    final appDocDir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(appDocDir.path, 'Later');

    // If no data folder path is set, use the default
    if (initialDataFolderPath.isEmpty) {
      initialDataFolderPath = defaultPath;
      debugPrint('Using default data folder path: $initialDataFolderPath');
    } else {
      // Test if the configured path is accessible
      final testFile = File(path.join(initialDataFolderPath, '.write_test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('Validated data folder path: $initialDataFolderPath');
      } catch (e) {
        // Path is not accessible, reset to default
        debugPrint(
            'Data folder path is not accessible: $initialDataFolderPath');
        debugPrint('Error: $e');
        debugPrint('Resetting to default path: $defaultPath');
        initialDataFolderPath = defaultPath;
      }
    }

    // Create the directory if it doesn't exist
    final directory = Directory(initialDataFolderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Save this path in settings
    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        settingsMap['dataFolderPath'] = initialDataFolderPath;
        await sharedPreferences.setString('settings', jsonEncode(settingsMap));
      } catch (e) {
        debugPrint('Error saving data folder path: $e');
      }
    }
  } catch (e) {
    debugPrint('Error setting up data folder path: $e');
  }

  // Create ProviderContainer to access providers before runApp
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      // Initialize dataFolderPathProvider with the validated path
      dataFolderPathProvider.overrideWith((ref) => initialDataFolderPath),
    ],
  );

  // Initialize the FileStorageService with the validated path
  final fileStorage = container.read(fileStorageServiceProvider);
  await fileStorage.initialize();

  // Initialize system tray (which also initializes window_manager)
  await container.read(systemTrayManagerProvider).initSystemTray();

  // Set up method channel for URL scheme handling
  const methodChannel = MethodChannel('com.later.app/url_scheme');
  methodChannel.setMethodCallHandler((call) async {
    if (call.method == 'handleUrl') {
      final url = call.arguments as String;
      await handleIncomingUrl(url, container);
    }
    return null;
  });

  // Handle initial URL if app was opened via URL scheme
  // Only try to use uni_links if not on macOS, since it's primarily for mobile platforms
  try {
    // On macOS, we rely on the MethodChannel for URL scheme handling
    // This is just a fallback for other platforms
    if (!Platform.isMacOS) {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        await handleIncomingUrl(initialLink, container);
      }
    }
  } catch (e) {
    // This is expected on macOS, so we just log it and continue
    debugPrint('Note: uni_links initial link not available: $e');
  }

  // Listen for incoming links while app is running
  // Only try to use uni_links if not on macOS
  if (!Platform.isMacOS) {
    try {
      linkStream.listen((String? link) async {
        if (link != null) {
          await handleIncomingUrl(link, container);
        }
      }, onError: (e) {
        debugPrint('Note: uni_links stream not available: $e');
      });
    } catch (e) {
      // This is expected on macOS, so we just log it and continue
      debugPrint('Note: uni_links stream setup failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        // Override the providers with the values we've already initialized
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        dataFolderPathProvider.overrideWith((ref) => initialDataFolderPath),
        // Override the FileStorageService with the already initialized instance
        fileStorageServiceProvider.overrideWithValue(fileStorage),
      ],
      child: const MainApp(),
    ),
  );
}

Future<void> handleIncomingUrl(String url, ProviderContainer container) async {
  debugPrint('Handling URL: $url');

  try {
    // Parse the URL
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return;
    }

    // Check if it's our custom scheme
    if (uri.scheme == 'later') {
      // Handle different paths
      if (uri.path == '/add' || uri.path.isEmpty) {
        // Extract URL data from query parameters
        final urlToAdd = uri.queryParameters['url'];
        final title = uri.queryParameters['title'] ?? 'Imported URL';
        final description = uri.queryParameters['description'];
        final categoryName = uri.queryParameters['category'];

        if (urlToAdd != null) {
          // Get the app notifier
          final appState = container.read(appNotifier);
          final appNotifierRef = container.read(appNotifier.notifier);

          // Find or create category if specified
          String categoryId = '';
          try {
            if (categoryName != null && categoryName.isNotEmpty) {
              // Check if category exists
              final categories = appState.categories;
              final existingCategory = categories
                  .where(
                      (c) => c.name.toLowerCase() == categoryName.toLowerCase())
                  .toList();

              if (existingCategory.isNotEmpty) {
                categoryId = existingCategory.first.id;
              } else {
                // Create new category
                final newCategory = Category(name: categoryName);
                appNotifierRef.addCategory(newCategory);
                categoryId = newCategory.id;
              }
            } else if (appState.categories.isNotEmpty) {
              // Use first category if none specified
              categoryId = appState.categories.first.id;
            }

            // Create and add URL
            final newUrl = UrlItem(
              url: urlToAdd,
              title: title,
              description: description,
              categoryId: categoryId,
            );

            await appNotifierRef.addUrl(newUrl);

            // Show notification
            LocalNotification(
              title: 'URL Added',
              body:
                  'Added URL: ${title.length > 30 ? "${title.substring(0, 27)}..." : title}',
            ).show();

            debugPrint('Added URL: $urlToAdd to category: $categoryName');
          } catch (e) {
            debugPrint('Error adding URL to database: $e');
          }
        }
      } else if (uri.path == '/import') {
        // Handle bulk import
        final jsonData = uri.queryParameters['data'];
        if (jsonData != null) {
          try {
            final decodedData = jsonDecode(jsonData) as Map<String, dynamic>;
            final importData = ExportData.fromJson(decodedData);
            container.read(appNotifier.notifier).importData(importData);

            // Show notification
            LocalNotification(
              title: 'URLs Imported',
              body:
                  'Imported ${importData.urls.length} URLs and ${importData.categories.length} categories',
            ).show();

            debugPrint(
                'Imported ${importData.urls.length} URLs and ${importData.categories.length} categories');
          } catch (e) {
            debugPrint('Error parsing import data: $e');
          }
        }
      } else if (uri.path == '/clipboard-import') {
        // Handle clipboard import
        debugPrint('Triggering clipboard import');

        // Bring the app to the foreground
        await windowManager.show();
        await windowManager.focus();

        // Trigger clipboard import
        // We need to use a slight delay to ensure the app is fully in the foreground
        Future.delayed(const Duration(milliseconds: 300), () {
          // Find the HomePage instance and trigger clipboard import
          // Force clipboard import regardless of settings
          _forceClipboardImport(container);
        });
      }
    }
  } catch (e) {
    debugPrint('Error handling URL scheme: $e');
  }
}

// Force clipboard import regardless of settings
void _forceClipboardImport(ProviderContainer container) async {
  try {
    // Get clipboard data
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData == null || clipboardData.text == null) return;

    final text = clipboardData.text!.trim();
    if (text.isEmpty) return;

    // Check if it's a JSON object (exported data)
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final decodedData = jsonDecode(text) as Map<String, dynamic>;

        // Check if it has the expected structure
        if (decodedData.containsKey('urls') &&
            decodedData.containsKey('version')) {
          final importData = ExportData.fromJson(decodedData);
          container.read(appNotifier.notifier).importData(importData);

          // Show notification
          LocalNotification(
            title: 'URLs Imported',
            body: 'Imported ${importData.urls.length} URLs from clipboard',
          ).show();

          return;
        }
      } catch (e) {
        debugPrint('Error parsing clipboard JSON: $e');
        // Not valid JSON, continue to URL check
      }
    }

    // Check if the text is a valid URL
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      // Try to prepend https:// and check if it's valid
      if (!Uri.tryParse('https://$text')!.hasAuthority) return;
    } else if (!Uri.tryParse(text)!.hasAuthority) {
      return;
    }

    // Check if URL already exists
    final appState = container.read(appNotifier);
    if (appState.urls.any((url) => url.url == text)) return;

    // Create a new URL item
    final categoryId = appState.selectedCategoryId ??
        (appState.categories.isNotEmpty ? appState.categories.first.id : '');

    // Create a basic URL item
    final newUrl = UrlItem(
      url: text,
      title: text, // Will be updated with metadata
      categoryId: categoryId,
    );

    // Add the URL and fetch metadata
    await container
        .read(appNotifier.notifier)
        .addUrl(newUrl, fetchMetadata: true);

    // Show notification
    LocalNotification(
      title: 'URL Imported',
      body: 'Imported URL from clipboard',
    ).show();
  } catch (e) {
    debugPrint('Error importing from clipboard: $e');
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifier);

    // Determine which theme to use
    MacosThemeData lightTheme;
    MacosThemeData darkTheme;

    if (settings.useCustomTheme) {
      // Use custom theme
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
