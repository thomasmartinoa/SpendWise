import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../backup_io.dart';
import '../../csv_io.dart';
import '../../data/snapshot_store.dart';
import '../../theme.dart';
import '../../widgets/charts/insight_card.dart';
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
          const SizedBox(height: 24),
          Text('Automatic snapshots',
              style: manrope(size: 12.5, weight: FontWeight.w700, color: c.ink2)),
          const SizedBox(height: 10),
          const _SnapshotSection(),
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

String _snapshotLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return 'Today $hm';
  if (diff == 1) return 'Yesterday $hm';
  return '${t.day} ${kMon[t.month - 1]} $hm';
}

/// Loads the local snapshot list once and renders it as tappable restore rows.
class _SnapshotSection extends StatefulWidget {
  const _SnapshotSection();
  @override
  State<_SnapshotSection> createState() => _SnapshotSectionState();
}

class _SnapshotSectionState extends State<_SnapshotSection> {
  final _store = SnapshotStore();
  late final Future<List<SnapshotInfo>> _future = _store.list();

  Future<void> _restore(BuildContext context, SnapshotInfo s) async {
    final app = context.read<AppState>();
    final go = await confirmDialog(
      context,
      title: 'Restore snapshot?',
      message:
          'Restoring this snapshot replaces all of your current data. This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!go || !context.mounted) return;
    final map = await _store.read(s.filename);
    if (!context.mounted) return;
    if (map == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that snapshot.')));
      return;
    }
    app.restoreFromBackup(map);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Snapshot restored.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<List<SnapshotInfo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final items = snap.data ?? const <SnapshotInfo>[];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: items.isEmpty
              ? const EmptyHint(
                  icon: Icons.history,
                  text: 'Snapshots appear here automatically as you use the app.')
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      InkWell(
                        onTap: () => _restore(context, items[i]),
                        child: Container(
                          decoration: i == items.length - 1
                              ? null
                              : BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(color: c.line2))),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.restore, size: 20, color: c.ink2),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(_snapshotLabel(items[i].time),
                                    style: manrope(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: c.ink)),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: c.ink2),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
