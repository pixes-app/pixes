import 'package:flutter/services.dart';
import 'package:pixes/foundation/app.dart';

/// Keeps the current window awake while a reading interaction is active.
///
/// Desktop platforms do not need a platform call here. Android and iOS
/// implement the channel in their host activities/app delegates.
class ScreenAwake {
  static const MethodChannel _channel = MethodChannel('pixes/screen_awake');

  static Future<void> setEnabled(bool enabled) async {
    if (!App.isMobile) return;
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', enabled);
    } on MissingPluginException {
      // Older platform builds may not have the channel yet.
    } on PlatformException {
      // Keeping the reader usable is more important than surfacing a native
      // screen-state failure.
    }
  }
}
