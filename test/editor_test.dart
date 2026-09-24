import 'package:flutter_test/flutter_test.dart';
import 'package:pachinko_sim/editor/block.dart';
import 'package:pachinko_sim/editor/board_layout.dart';
import 'package:pachinko_sim/editor/editor_controller.dart';
import 'package:pachinko_sim/editor/layout_presets.dart';
import 'package:pachinko_sim/engine/game_controller.dart';
import 'package:pachinko_sim/engine/vec2.dart';
import 'package:pachinko_sim/models/board_pattern.dart';

/// 2つの座標リストが（順不同で）1対1に一致するか。
void expectSamePositions(List<Vec2> a, List<Vec2> b, {double eps = 1e-6}) {
  expect(a.length, b.length, reason: '個数が違う: ${a.length} vs ${b.length}');
  final remaining = List<Vec2>.of(b);
  for (final p in a) {
    final i = remaining.indexWhere((q) => (p - q).length < eps);
    expect(i, isNot(-1), reason: '$p に対応する座標がない');
    remaining.removeAt(i);
  }
  expect(remaining, isEmpty);
}

void main() {
  group('ブロック/レイアウトのモデル', () {
    test('グリッドは 8x8＝1セルが台の1/64', () {
      expect(kGridCols * kGridRows, 64);
      expect(kCellW * kGridCols, closeTo(kBoardWidth, 1e-9));
      expect(kCellH * kGridRows, closeTo(kBoardHeight, 1e-9));
    });

    test('JSON ラウンドトリップで内容が保たれる', () {
      final layout = buildPhase1Layout();
      final restored = BoardLayout.fromJson(
          Map<String, dynamic>.from(layout.toJson()));

      final a = layout.compile();
      final b = restored.compile();
      expectSamePositions(
        a.nails.map((n) => n.pos).toList(),
        b.nails.map((n) => n.pos).toList(),
      );
      expect(b.holes.length, a.holes.length);
      expect(b.slots.length, a.slots.length);
      expect(b.tulips.length, a.tulips.length);
      expect(b.rotors.length, a.rotors.length);
    });
  });

  group('既存台の再現', () {
    final pattern = Phase1StandardPattern();
    final cfg = BoardConfig.defaults();
    final compiled = buildPhase1Layout().compile();

    test('釘の座標が既存台と一致する', () {
      final expected = pattern.buildNails(cfg).map((n) => n.pos).toList();
      final got = compiled.nails.map((n) => n.pos).toList();
      expectSamePositions(got, expected);
    });

    test('入賞穴の座標・賞球が一致する', () {
      final expected = pattern.buildWinningHoles();
      expect(compiled.holes.length, expected.length);
      for (final e in expected) {
        final m = compiled.holes.firstWhere(
          (h) => (h.pos - e.pos).length < 1e-6,
          orElse: () => throw StateError('穴なし ${e.pos}'),
        );
        expect(m.payout, e.payout);
      }
    });

    test('チューリップの座標が一致する', () {
      final expected = pattern.buildTulip(cfg);
      expect(compiled.tulips.length, 1);
      expect((compiled.tulips.single.base - expected.base).length,
          lessThan(1e-6));
    });

    test('スロットの座標が一致する', () {
      final expected = pattern.buildSlot()!;
      expect(compiled.slots.length, 1);
      expect((compiled.slots.single.center - expected.center).length,
          lessThan(1e-6));
    });

    test('回転体はスロットから自動生成され、既存台の左右2基と一致する', () {
      final expected = pattern.buildRotors().map((r) => r.center).toList();
      final got = compiled.rotors.map((r) => r.center).toList();
      expect(got.length, 2);
      expectSamePositions(got, expected);
    });
  });

  group('EditorController の基本操作', () {
    test('ブロック追加・削除・配置追加・削除', () {
      final ec = EditorController(buildPhase1Layout());
      final blockCount0 = ec.layout.blocks.length;
      final placeCount0 = ec.layout.placements.length;

      ec.addBlock();
      expect(ec.layout.blocks.length, blockCount0 + 1);
      expect(ec.selectedBlockId, ec.layout.blocks.last.id);

      // 新規ブロックに釘を1本足す
      ec.paletteKind = ElementKind.nail;
      ec.addElementAt(const Vec2(5, 5));
      expect(ec.selectedBlock!.elements.length, 1);

      // 配置に追加
      ec.placeSelectedBlockAt(0, 0);
      expect(ec.layout.placements.length, placeCount0 + 1);

      // ブロック削除でその配置も消える
      ec.deleteSelectedBlock();
      expect(ec.layout.blocks.length, blockCount0);
      expect(ec.layout.placements.length, placeCount0);
    });

    test('配置を移動・削除できる', () {
      final ec = EditorController(buildPhase1Layout());
      ec.selectPlacement(0);
      ec.moveSelectedPlacement(3, 3);
      expect(ec.layout.placements[0].col, 3);
      expect(ec.layout.placements[0].row, 3);
      final n = ec.layout.placements.length;
      ec.deleteSelectedPlacement();
      expect(ec.layout.placements.length, n - 1);
    });

    test('ブロックを別グリッドへ動かすと台の座標も動く', () {
      final ec = EditorController(buildPhase1Layout());
      // 'tulip' ブロックの配置を探す
      final pi = ec.layout.placements
          .indexWhere((p) => p.blockId == 'tulip');
      final before = ec.layout.compile().tulips.single.base;
      ec.selectPlacement(pi);
      final p = ec.layout.placements[pi];
      ec.moveSelectedPlacement(p.col + 1, p.row);
      final after = ec.layout.compile().tulips.single.base;
      expect((after.x - before.x), closeTo(kCellW, 1e-6));
      expect(after.y, closeTo(before.y, 1e-6));
    });
  });

  group('カスタムレイアウトでの遊技', () {
    test('applyLayout でカスタム台に切替→発射しても詰まらない', () {
      final c = GameController()
        ..setInitialBallCount(4000);
      c.applyLayout(buildPhase1Layout());
      expect(c.usingCustomLayout, isTrue);
      expect(c.world.slots.length, 1);
      expect(c.world.rotors.length, 2);

      c.setStrength(56);
      for (var i = 0; i < 200; i++) {
        c.manualLaunch();
        for (var k = 0; k < 8; k++) {
          c.tick(1 / 60);
        }
      }
      for (var k = 0; k < 60 * 90; k++) {
        c.tick(1 / 60);
      }
      expect(c.world.ballCount, 0);
      expect(c.world.forcedDrains, 0);
      final s = c.stats;
      expect(s.foul + s.out + s.tulipIn + s.winning + s.slotPlays, s.launched);
    });

    test('applyLayout(null) で既定台へ戻る', () {
      final c = GameController();
      c.applyLayout(buildPhase1Layout());
      expect(c.usingCustomLayout, isTrue);
      c.applyLayout(null);
      expect(c.usingCustomLayout, isFalse);
      expect(c.world.slots.length, 1);
    });
  });
}
