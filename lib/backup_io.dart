import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';

/// Exports the full app state as a lossless JSON file via the share sheet.
Future<void> exportJson(AppState app) async {
  final json = jsonEncode(app.backupMap());
  final bytes = Uint8List.fromList(utf8.encode(json));
  final file = XFile.fromData(bytes,
      mimeType: 'application/json', name: 'spendwise-backup.json');
  await Share.shareXFiles([file]);
  app.markBackedUp();
}

/// Picks a JSON backup and restores it. Returns null if cancelled,
/// else true/false for parse success.
Future<bool?> importJson(AppState app) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  final bytes = res?.files.single.bytes;
  if (bytes == null) return null;
  try {
    final map = jsonDecode(utf8.decode(bytes, allowMalformed: true))
        as Map<String, dynamic>;
    app.restoreFromBackup(map);
    return true;
  } catch (_) {
    return false;
  }
}
