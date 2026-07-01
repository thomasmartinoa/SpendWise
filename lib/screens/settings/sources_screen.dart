import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'settings_widgets.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Income sources',
            style: manrope(
                size: 18, weight: FontWeight.w700, color: AppColors.of(context).ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...app.sources.map((s) => Container(
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: c.line2))),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          MiniBox(
                              text: '+',
                              bg: Brand.greenTintBg,
                              fg: Brand.green,
                              size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(s,
                                style: manrope(
                                    size: 14.5,
                                    weight: FontWeight.w700,
                                    color: c.ink)),
                          ),
                          DeleteX(onTap: () => app.delSource(s)),
                        ],
                      ),
                    )),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: SoftField(
                        value: app.newSourceName,
                        hint: 'New income source',
                        onChanged: (v) => app.set(() => app.newSourceName = v),
                      ),
                    ),
                    const SizedBox(width: 9),
                    AddButton(
                        label: 'Add', color: Brand.green, onTap: app.addSource),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
