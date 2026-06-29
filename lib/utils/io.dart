import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pixes/foundation/app.dart';

extension FSExt on FileSystemEntity {
  Future<void> deleteIfExists() async {
    if (await exists()) {
      await delete();
    }
  }

  Future<void> deleteIgnoreError() async {
    try {
      await delete();
    } catch (e) {
      // ignore
    }
  }

  int get size {
    if (this is File) {
      return (this as File).lengthSync();
    } else if(this is Directory){
      var size = 0;
      for(var file in (this as Directory).listSync()){
        size += file.size;
      }
      return size;
    }
    return 0;
  }
}

extension DirectoryExt on Directory {
  bool havePermission() {
    try {
      if(!existsSync()) return false;
      if(App.isMacOS) {
        return true;
      }
      listSync();
      return true;
    } catch (e) {
      return false;
    }
  }
}

String bytesToText(int bytes) {
  if(bytes < 1024) {
    return "$bytes B";
  } else if(bytes < 1024 * 1024) {
    return "${(bytes / 1024).toStringAsFixed(2)} KB";
  } else if(bytes < 1024 * 1024 * 1024) {
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  } else {
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}

void saveFile(File file, [String? name]) async{
  if(App.isDesktop) {
    var fileName = file.path.split('/').last;
    final FileSaveLocation? result =
    await getSaveLocation(suggestedName: name ?? fileName);
    if (result == null) {
      return;
    }

    final Uint8List fileData = await file.readAsBytes();
    String mimeType = 'image/${fileName.split('.').last}';
    final XFile textFile = XFile.fromData(
        fileData, mimeType: mimeType, name: name ?? fileName);
    await textFile.saveTo(result.path);
  } else {
    final params = SaveFileDialogParams(sourceFilePath: file.path, fileName: name);
    await FlutterFileDialog.saveFile(params: params);
  }
}