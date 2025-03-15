import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appNotifier);
    final settings = ref.watch(settingsNotifier);

    return MacosScaffold(
      toolBar: ToolBar(
        leading: MacosIconButton(
          icon: const MacosIcon(
            CupertinoIcons.sidebar_left,
            size: 20,
          ),
          onPressed: () {
            MacosWindowScope.of(context).toggleSidebar();
          },
        ),
        title: const Text('Settings'),
        titleWidth: 150,
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildThemeSelector(context, ref, settings),
                  const SizedBox(height: 32),
                  Text(
                    'Data Storage',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildDataFolderSelector(context, ref, settings),
                  const SizedBox(height: 16),
                  _buildClearDataButton(context, ref),
                  const SizedBox(height: 32),
                  Text(
                    'System Tray',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildSystemTraySettings(context, ref, settings),
                  const SizedBox(height: 32),
                  Text(
                    'Browser Extensions',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  _buildBrowserExtensionsInfo(context),
                  const SizedBox(height: 32),
                  Text(
                    'About',
                    style: MacosTheme.of(context).typography.title1,
                  ),
                  const SizedBox(height: 16),
                  MacosListTile(
                    title: const Text('Version'),
                    subtitle: Text(appState.appVersion),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        MacosSegmentedControl<ThemeMode>(
          segments: const {
            ThemeMode.system: MacosSegmentedControlSegment(label: 'System'),
            ThemeMode.light: MacosSegmentedControlSegment(label: 'Light'),
            ThemeMode.dark: MacosSegmentedControlSegment(label: 'Dark'),
          },
          value: settings.themeMode,
          onValueChanged: (value) {
            ref.read(settingsNotifier.notifier).setThemeMode(value);
          },
        ),
      ],
    );
  }

  Widget _buildDataFolderSelector(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Folder',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MacosTheme.of(context).canvasColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: MacosColors.systemGrayColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  settings.dataFolderPath.isEmpty ? 'Default location' : settings.dataFolderPath,
                  style: MacosTheme.of(context).typography.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              onPressed: () async {
                final selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  ref.read(settingsNotifier.notifier).setDataFolderPath(selectedDirectory);
                }
              },
              child: const Text('Choose Folder'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClearDataButton(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clear Data',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          secondary: true,
          onPressed: () {
            _showClearDataConfirmationDialog(context, ref);
          },
          child: const Text('Clear All Data'),
        ),
        const SizedBox(height: 4),
        Text(
          'This will delete all categories and URLs',
          style: MacosTheme.of(context).typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
              ),
        ),
      ],
    );
  }

  Widget _buildSystemTraySettings(BuildContext context, WidgetRef ref, Settings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MacosCheckbox(
              value: settings.showSystemTrayIcon,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setShowSystemTrayIcon(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Show icon in system tray',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MacosCheckbox(
              value: settings.startMinimized,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setStartMinimized(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Start app minimized',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MacosCheckbox(
              value: settings.autoImportFromClipboard,
              onChanged: (value) {
                ref.read(settingsNotifier.notifier).setAutoImportFromClipboard(value);
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Auto-import URLs from clipboard',
              style: MacosTheme.of(context).typography.body,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrowserExtensionsInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chrome Extension',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Text(
          'Install the Chrome extension to easily save tabs from your browser.',
          style: MacosTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          onPressed: () {
            // Open Chrome extension page
          },
          child: const Text('Install Chrome Extension'),
        ),
        const SizedBox(height: 16),
        Text(
          'Firefox Extension',
          style: MacosTheme.of(context).typography.headline,
        ),
        const SizedBox(height: 8),
        Text(
          'Install the Firefox extension to easily save tabs from your browser.',
          style: MacosTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        PushButton(
          controlSize: ControlSize.regular,
          onPressed: () {
            // Open Firefox extension page
          },
          child: const Text('Install Firefox Extension'),
        ),
      ],
    );
  }

  void _showClearDataConfirmationDialog(BuildContext context, WidgetRef ref) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
        title: const Text('Clear All Data'),
        message: const Text(
          'Are you sure you want to clear all data? This will delete all categories and URLs and cannot be undone.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            ref.read(settingsNotifier.notifier).clearAllData();
            Navigator.of(context).pop();
          },
          child: const Text('Clear Data'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
