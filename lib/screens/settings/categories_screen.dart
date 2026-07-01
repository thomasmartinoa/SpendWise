import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'settings_widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context
        .read<AppState>()
        .set(() => context.read<AppState>().newCatColor =
            context.read<AppState>().firstUnusedCatColor()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Expense categories',
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
                ...app.cats.map((cc) => Container(
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: c.line2))),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          MiniBox(
                              text: cc.label.isNotEmpty
                                  ? cc.label[0].toUpperCase()
                                  : '?',
                              bg: cc.color,
                              fg: Colors.white,
                              size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(cc.label,
                                style: manrope(
                                    size: 14.5,
                                    weight: FontWeight.w700,
                                    color: c.ink)),
                          ),
                          DeleteX(onTap: () => app.delCat(cc.key)),
                        ],
                      ),
                    )),
                const SizedBox(height: 14),
                // palette
                Wrap(
                  spacing: 7,
                  children: kPalette.map<Widget>((col) {
                    final sel = app.newCatColor == col;
                    return GestureDetector(
                      onTap: () => app.set(() => app.newCatColor = col),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: sel ? c.ink : Colors.transparent,
                              width: 2.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: SoftField(
                        value: app.newCatName,
                        hint: 'New category name',
                        onChanged: (v) => app.set(() => app.newCatName = v),
                      ),
                    ),
                    const SizedBox(width: 9),
                    AddButton(
                        label: 'Add', color: Brand.accent, onTap: app.addCat),
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
