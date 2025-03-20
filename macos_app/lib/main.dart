import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide VoidCallbackIntent, VoidCallbackAction;
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:window_manager/window_manager.dart';

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

  // Get initial data folder path from settings
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

  // Create ProviderContainer to access providers before runApp
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      // Initialize dataFolderPathProvider with the path from settings
      dataFolderPathProvider.overrideWith((ref) => initialDataFolderPath),
    ],
  );

  // Initialize system tray (which also initializes window_manager)
  await container.read(systemTrayManagerProvider).initSystemTray();

  // Set up method channel for URL scheme handling
  const methodChannel = MethodChannel('com.later.app/url_scheme');
  methodChannel.setMethodCallHandler((call) async {
    if (call.method == 'handleUrl') {
      final url = call.arguments as String;
      handleIncomingUrl(url, container);
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
        handleIncomingUrl(initialLink, container);
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
      linkStream.listen((String? link) {
        if (link != null) {
          handleIncomingUrl(link, container);
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
      parent: container,
      child: const MainApp(),
    ),
  );
}

void handleIncomingUrl(String url, ProviderContainer container) {
  debugPrint('Handling URL: $url');

  try {
    // Parse the URL
    final uri = Uri.parse(url);

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
          if (categoryName != null && categoryName.isNotEmpty) {
            // Check if category exists
            final categories = appState.categories;
            final existingCategory = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase()).toList();

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

          appNotifierRef.addUrl(newUrl);

          // Show notification
          LocalNotification(
            title: 'URL Added',
            body: 'Added URL: ${title.length > 30 ? title.substring(0, 27) + '...' : title}',
          ).show();

          debugPrint('Added URL: $urlToAdd to category: $categoryName');
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
              body: 'Imported ${importData.urls.length} URLs and ${importData.categories.length} categories',
            ).show();

            debugPrint('Imported ${importData.urls.length} URLs and ${importData.categories.length} categories');
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
          final navigatorState = DialogService.navigatorKey.currentState;
          if (navigatorState != null) {
            final context = navigatorState.context;

            // Force clipboard import regardless of settings
            _forceClipboardImport(context, container);
          }
        });
      }
    }
  } catch (e) {
    debugPrint('Error handling URL: $e');
  }
}

// Force clipboard import regardless of settings
void _forceClipboardImport(BuildContext context, ProviderContainer container) async {
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
        if (decodedData.containsKey('urls') && decodedData.containsKey('version')) {
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
    final categoryId = appState.selectedCategoryId ?? (appState.categories.isNotEmpty ? appState.categories.first.id : '');

    // Create a basic URL item
    final newUrl = UrlItem(
      url: text,
      title: text, // Will be updated with metadata
      categoryId: categoryId,
    );

    // Add the URL and fetch metadata
    await container.read(appNotifier.notifier).addUrl(newUrl, fetchMetadata: true);

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

    return MacosApp(
      navigatorKey: DialogService.navigatorKey,
      title: 'Later',
      theme: lightTheme,
      darkTheme: darkTheme,
      color: Colors.transparent,
      themeMode: settings.themeMode,
      home: Builder(
        builder: (context) {
          // Create shortcuts map
          final shortcuts = KeyboardShortcuts.getApplicationShortcuts(context, ref);

          return Shortcuts(
            shortcuts: Map.fromEntries(
              shortcuts.keys.map((key) => MapEntry(key, VoidCallbackIntent(shortcuts[key]!))),
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
      routes: {
        '/settings': (context) => const SettingsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
