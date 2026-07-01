import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../backup_io.dart';
import '../../csv_io.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'settings_widgets.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Backup & restore',
            style: manrope(
                size: 18, weight: FontWeight.w700, color: AppColors.of(context).ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
              app.lastBackup == null
                  ? 'Never backed up.'
                  : 'Last backup: ${_ago(app.lastBackup!)}',
              style: manrope(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: app.lastBackup == null ? Brand.accent : c.ink2)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                BackupRow(
                  iconBg: Brand.greenTintBg,
                  iconColor: Brand.green,
                  glyph: '↓',
                  title: 'Export to CSV',
                  sub: 'download a backup file',
                  divider: true,
                  onTap: () => exportCsv(app),
                ),
                BackupRow(
                  iconBg: Brand.tintBg,
                  iconColor: Brand.accent,
                  glyph: '↑',
                  title: 'Import from CSV',
                  sub: 'restore from a backup',
                  divider: true,
                  onTap: () async {
                    final go = await confirmDialog(
                      context,
                      title: 'Import backup?',
                      message:
                          'Importing a CSV replaces all of your current transactions and income. This cannot be undone.',
                      confirmLabel: 'Import',
                    );
                    if (!go || !context.mounted) return;
                    final ok = await importCsv(app);
                    if (ok != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Backup imported.'
                              : 'Could not read that file.')));
                    }
                  },
                ),
                BackupRow(
                  iconBg: Brand.greenTintBg,
                  iconColor: Brand.green,
                  glyph: '↓',
                  title: 'Export backup (JSON)',
                  sub: 'download a lossless backup file',
                  divider: true,
                  onTap: () => exportJson(app),
                ),
                BackupRow(
                  iconBg: Brand.tintBg,
                  iconColor: Brand.accent,
                  glyph: '↑',
                  title: 'Restore backup (JSON)',
                  sub: 'restore from a lossless backup',
                  divider: false,
                  onTap: () async {
                    final go = await confirmDialog(
                      context,
                      title: 'Restore backup?',
                      message:
                          'Restoring a JSON backup replaces all of your current data. This cannot be undone.',
                      confirmLabel: 'Restore',
                    );
                    if (!go || !context.mounted) return;
                    final ok = await importJson(app);
                    if (ok != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Backup restored.'
                              : 'Could not read that file.')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(String iso) {
  final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  return '$d days ago';
}
