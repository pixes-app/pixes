import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixes/utils/io.dart';

import 'foundation/app.dart';
import 'foundation/log.dart';
import 'network/models.dart';

class _Appdata {
  static const MethodChannel _macosDownloadPathChannel =
      MethodChannel("pixes/macos/download_path");

  Account? account;

  var searchOptions = SearchOptions();

  Map<String, dynamic> settings = {
    "downloadPath": null,
    "downloadSubPath": r"/${id}-p${index}.${ext}",
    "maxParallels": 3,
    "proxy": "",
    "darkMode": "System",
    "language": "System",
    "readingFontSize": 16.0,
    "readingLineHeight": 1.5,
    "readingParagraphSpacing": 8.0,
    "blockTags": [],
    "shortcuts": <int>[
      LogicalKeyboardKey.arrowDown.keyId,
      LogicalKeyboardKey.arrowUp.keyId,
      LogicalKeyboardKey.arrowRight.keyId,
      LogicalKeyboardKey.arrowLeft.keyId,
      LogicalKeyboardKey.enter.keyId,
      LogicalKeyboardKey.keyD.keyId,
      LogicalKeyboardKey.keyF.keyId,
      LogicalKeyboardKey.keyC.keyId,
      LogicalKeyboardKey.keyG.keyId,
    ],
    "showOriginalImage": false,
    "checkUpdate": true,
    "emphasizeArtworksFromFollowingArtists": true,
    "initialPage": 4,
  };

  bool lock = false;

  void writeData() async {
    while (lock) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    lock = true;
    await File("${App.dataPath}/account.json")
        .writeAsString(jsonEncode(account));
    await File("${App.dataPath}/settings.json")
        .writeAsString(jsonEncode(settings));
    lock = false;
  }

  void writeSettings() async {
    while (lock) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    lock = true;
    await File("${App.dataPath}/settings.json")
        .writeAsString(jsonEncode(settings));
    lock = false;
  }

  Future<void> readData() async {
    final file = File("${App.dataPath}/account.json");
    if (file.existsSync()) {
      var json = jsonDecode(await file.readAsString());
      if (json != null) {
        account = Account.fromJson(json);
      }
    }
    final settingsFile = File("${App.dataPath}/settings.json");
    if (settingsFile.existsSync()) {
      var json = jsonDecode(await settingsFile.readAsString());
      for (var key in json.keys) {
        if (json[key] != null) {
          if (json[key] is List && settings[key] is List) {
            for (int i = 0;
                i < json[key].length && i < settings[key].length;
                i++) {
              settings[key][i] = json[key][i];
            }
          } else {
            settings[key] = json[key];
          }
        }
      }
    }
    settings["downloadPath"] ??= await _defaultDownloadPath;
    if (App.isMacOS) {
      await _ensureMacOSDownloadPathPermission();
    }
  }

  Future<void> _ensureMacOSDownloadPathPermission() async {
    final defaultPath = await _defaultDownloadPath;
    final currentPath = settings["downloadPath"] as String? ?? defaultPath;
    if (_normalizePath(currentPath) == _normalizePath(defaultPath)) {
      settings["downloadPath"] = defaultPath;
      return;
    }

    final restoredPath = await _restoreMacOSDownloadPathAccess(currentPath);
    if (restoredPath != null) {
      settings["downloadPath"] = restoredPath;
      Log.info(
          "DownloadPath", "Restored macOS directory access: $restoredPath");
      return;
    }

    Log.warning(
      "DownloadPath",
      "Failed to restore macOS directory access for $currentPath, requesting permission again.",
    );
    final selectedPath = await _requestMacOSDownloadPathAccess(currentPath);
    if (selectedPath != null) {
      settings["downloadPath"] = selectedPath;
      writeSettings();
      Log.info(
        "DownloadPath",
        "Re-authorized macOS directory access: $selectedPath",
      );
      return;
    }

    settings["downloadPath"] = defaultPath;
    writeSettings();
    Log.warning(
      "DownloadPath",
      "macOS directory permission denied or canceled, fallback to default path: $defaultPath",
    );
  }

  Future<String?> _restoreMacOSDownloadPathAccess(String? expectedPath) async {
    try {
      return await _macosDownloadPathChannel.invokeMethod<String>(
        "restoreDownloadDirectoryAccess",
        {"path": expectedPath},
      );
    } catch (e) {
      Log.warning("DownloadPath", "restoreDownloadDirectoryAccess failed: $e");
      return null;
    }
  }

  Future<String?> _requestMacOSDownloadPathAccess(String? initialPath) async {
    try {
      return await _macosDownloadPathChannel.invokeMethod<String>(
        "selectDownloadDirectory",
        {"initialPath": initialPath},
      );
    } catch (e) {
      Log.warning("DownloadPath", "selectDownloadDirectory failed: $e");
      return null;
    }
  }

  String _normalizePath(String path) {
    if (!App.isMacOS) {
      return path;
    }
    final home = Platform.environment["HOME"];
    if (home != null && path.startsWith("~")) {
      return path.replaceFirst("~", home);
    }
    return path;
  }

  Future<String> get _defaultDownloadPath async {
    if (App.isAndroid) {
      String? downloadPath = "/storage/emulated/0/download";
      if (!Directory(downloadPath).havePermission()) {
        downloadPath = null;
      }
      var res = downloadPath;
      res ??= (await getExternalStorageDirectory())!.path;
      return "$res/pixes";
    } else if (App.isWindows) {
      var res =
          await const MethodChannel("pixes/picture_folder").invokeMethod("");
      if (res != "error") {
        return res + "/pixes";
      }
    } else if (App.isLinux) {
      var downloadPath = (await getDownloadsDirectory())?.path;
      if (downloadPath != null && Directory(downloadPath).havePermission()) {
        return "$downloadPath/pixes";
      }
    } else if (App.isMacOS) {
      if (Directory("~/Pictures").havePermission()) {
        return "~/Pictures/pixes";
      }
      try {
        Directory("~/Downloads/pixes").createSync(recursive: true);
        return "~/Downloads/pixes";
      } catch (e) {
        return "${App.dataPath}/download";
      }
    }

    return "${App.dataPath}/download";
  }
}

final appdata = _Appdata();
