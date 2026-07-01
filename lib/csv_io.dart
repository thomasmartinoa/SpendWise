import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';

/// Builds the CSV backup and hands it to the platform share sheet
/// (download dialog on web, share sheet on mobile/desktop).
Future<void> exportCsv(AppState app) async {
  final csv = app.buildCsv();
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final file = XFile.fromData(
    bytes,
    mimeType: 'text/csv',
    name: 'expense-backup.csv',
  );
  await Share.shareXFiles([file]);
  app.markBackedUp();
}

/// Opens the file picker, reads a CSV and replaces the dataset.
/// Returns null if cancelled, otherwise true/false for parse success.
Future<bool?> importCsv(AppState app) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  final bytes = res?.files.single.bytes;
  if (bytes == null) return null;
  final content = utf8.decode(bytes, allowMalformed: true);
  return app.importCsv(content);
}
