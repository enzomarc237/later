import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

/// A dialog that shows information about the Later app.
void showAboutLaterDialog(BuildContext context) {
  showMacosAlertDialog(
    context: context,
    builder: (context) {
      return MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.info_circle,
          size: 56,
        ),
        title: const Text('About Later'),
        message: const Text(
          'A simple bookmarking app for macOS.',
          textAlign: TextAlign.center,
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            // Open the GitHub repository
          },
          child: const Text('GitHub'),
        ),
      );
    },
  );
}

