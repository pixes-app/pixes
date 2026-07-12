import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../appdata.dart';

export "widget_utils.dart";
export "state_controller.dart";
export "navigation.dart";

class _App {
  final version = "1.2.3";

  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;
  bool get isWindows => Platform.isWindows;
  int? _windowsVersion;
  int get windowsVersion => _windowsVersion!;
  bool get isLinux => Platform.isLinux;
  bool get isMacOS => Platform.isMacOS;
  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  Locale get locale {
    if (appdata.settings["language"] != "System") {
      return switch (appdata.settings["language"]) {
        "English" => const Locale("en"),
        "简体中文" => const Locale("zh", "CN"),
        "繁體中文" => const Locale("zh", "TW"),
        _ => const Locale("en"),
      };
    }
    Locale deviceLocale = PlatformDispatcher.instance.locale;
    if (deviceLocale.languageCode == "zh" &&
        deviceLocale.scriptCode == "Hant") {
      deviceLocale = const Locale("zh", "TW");
    }
    return deviceLocale;
  }

  late String dataPath;
  late String cachePath;

  init() async {
    cachePath = (await getApplicationCacheDirectory()).path;
    dataPath = (await getApplicationSupportDirectory()).path;
    if (App.isWindows) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.windowsInfo;
      if (deviceInfo.majorVersion <= 6) {
        if (deviceInfo.minorVersion < 2) {
          _windowsVersion = 7;
        } else {
          _windowsVersion = 8;
        }
      } else if (deviceInfo.buildNumber < 22000) {
        _windowsVersion = 10;
      } else {
        _windowsVersion = 11;
      }
    }
  }

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState>? mainNavigatorKey;
}

// ignore: non_constant_identifier_names
final App = _App();
