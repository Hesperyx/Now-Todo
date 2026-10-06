/// 备份文件的落地：写出去、收回来。
///
/// 这一层**只做平台 I/O**，不碰格式：文本怎么编、怎么解归
/// `lib/core/backup/backup_codec.dart`。分开的好处是界面测试可以注入一个
/// 假的实现（喂一段坏文本、看它报什么），不必真去弹文件选择器。
///
/// 导出走「写进临时目录 + 系统分享面板」：这样用户既能存到文件管理器，也能
/// 直接发给自己。存哪儿由系统面板决定，应用不需要存储权限。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 文件读写失败时抛这个。消息直接给用户看，所以里面不放异常类型名。
class BackupFileException implements Exception {
  const BackupFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class BackupFileService {
  /// 把 [text] 写成 [fileName] 并拉起系统分享面板。
  Future<void> share(String text, {required String fileName, String? subject});

  /// 让用户挑一个文件，返回它的文本；用户取消时返回 `null`。
  ///
  /// 区分「取消」和「读失败」很重要：取消不该弹错误提示。
  Future<String?> pickText();
}

/// 真机上的实现。
class FileBackupService implements BackupFileService {
  const FileBackupService();

  /// 分享用的 MIME。写死而不是按扩展名猜：这个类型一共就一种。
  static const String _mimeType = 'application/json';

  @override
  Future<void> share(
    String text, {
    required String fileName,
    String? subject,
  }) async {
    final File file;
    try {
      final Directory directory = await getTemporaryDirectory();
      file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(text, flush: true);
    } on Object catch (error) {
      throw BackupFileException('写不出备份文件：$error');
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: _mimeType)],
          subject: subject,
        ),
      );
    } on Object catch (error) {
      throw BackupFileException('打不开分享面板：$error');
    }
  }

  @override
  Future<String?> pickText() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
      );
    } on Object catch (error) {
      throw BackupFileException('打不开文件选择器：$error');
    }
    if (result == null || result.files.isEmpty) return null;

    final PlatformFile file = result.files.first;
    // 应用私有目录之外的文件不一定给得到路径（Android 上走的是内容 URI），
    // 所以优先用插件直接读出来的字节。
    final Uint8List? bytes = file.bytes;
    if (bytes != null) return utf8.decode(bytes, allowMalformed: true);

    final String? path = file.path;
    if (path == null) {
      throw const BackupFileException('这个文件读不出来，换一个试试。');
    }
    try {
      return await File(path).readAsString();
    } on Object catch (error) {
      throw BackupFileException('读文件失败：$error');
    }
  }
}
