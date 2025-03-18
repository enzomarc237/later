import 'package:flutter/material.dart';

/// An intent that executes a callback when invoked.
class VoidCallbackIntent extends Intent {
  /// Creates an intent that executes [callback] when invoked.
  const VoidCallbackIntent(this.callback);

  /// The callback to execute when the intent is invoked.
  final VoidCallback callback;
}

/// An action that executes a callback when invoked.
class VoidCallbackAction extends Action<VoidCallbackIntent> {
  @override
  Object? invoke(VoidCallbackIntent intent) {
    intent.callback();
    return null;
  }
}