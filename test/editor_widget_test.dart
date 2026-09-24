import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pachinko_sim/ui/home_page.dart';

/// 遊技モードはゲームループ（Ticker）が回り続けるので pumpAndSettle は使わず、
/// 固定時間だけ pump してフレームを進める。
void main() {
  testWidgets('遊技⇔編集を切り替えられ、編集の両サブモードが表示される',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('発射'), findsOneWidget);
    expect(find.text('編集'), findsWidgets);

    await tester.tap(find.text('編集').first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('配置編集'), findsWidgets);
    expect(find.text('ブロック編集'), findsWidgets);
    expect(find.text('プレイに反映'), findsOneWidget);

    await tester.tap(find.text('ブロック編集').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ブロック名'), findsOneWidget);

    await tester.tap(find.text('配置編集').first);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('プレイに反映'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('発射'), findsOneWidget);
  });

  testWidgets('編集モードで既定レイアウトを読込できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('編集').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('既定レイアウト読込'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('プレイに反映'), findsOneWidget);
  });
}
