import 'dart:io';

import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directories_provider.g.dart';

@Riverpod(keepAlive: true)
class AppDirectories extends _$AppDirectories with InfraLogger {
  @override
  Future<Directories> build() async {
    final baseDir = await getApplicationSupportDirectory();
    final workingDir =
        Platform.isAndroid ? await getExternalStorageDirectory() : baseDir;
    final tempDir = await getTemporaryDirectory();
    final dirs = (
      baseDir: baseDir,
      workingDir: workingDir!,
      tempDir: tempDir,
    );

    if (!dirs.baseDir.existsSync()) {
      await dirs.baseDir.create(recursive: true);
    }
    if (!dirs.workingDir.existsSync()) {
      await dirs.workingDir.create(recursive: true);
    }

    return dirs;
  }

  static Future<Directory> getDatabaseDirectory() async {
    if (Platform.isWindows || Platform.isLinux) {
      return getApplicationSupportDirectory();
    }
    return getApplicationDocumentsDirectory();
  }
}
