import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/theme.dart';
import 'package:spendwise/widgets/charts/insight_card.dart';

void main() {
  testWidgets('InsightCard shows title and child; EmptyHint shows text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(false),
      home: const Scaffold(
        body: InsightCard(
          title: 'My Card',
          caption: 'a caption',
          child: Text('body-here'),
        ),
      ),
    ));
    expect(find.text('My Card'), findsOneWidget);
    expect(find.text('a caption'), findsOneWidget);
    expect(find.text('body-here'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(false),
      home: const Scaffold(
        body: EmptyHint(icon: Icons.info_outline, text: 'nothing here'),
      ),
    ));
    expect(find.text('nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
