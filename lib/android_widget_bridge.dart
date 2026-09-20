import 'package:flutter/services.dart';

import 'android_widget_snapshot.dart';

/// Updates Android home-screen widgets. On Windows and other platforms the
/// method channel is simply unavailable, so updates safely become no-ops.
class AndroidWidgetBridge {
  static const _channel = MethodChannel('dzien_po_dniu/widgets');

  Future<void> update(AndroidWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('updateWidgets', snapshot.toChannelPayload());
    } on MissingPluginException {
      // Widgets are Android-only.
    } on PlatformException {
      // A widget update must never block a task or note save.
    }
  }
}
