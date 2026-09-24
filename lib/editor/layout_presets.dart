import '../engine/vec2.dart';
import '../models/board_pattern.dart';
import 'block.dart';
import 'board_layout.dart';

/// 既存の Phase1 標準台を「ブロック＋配置」へ分解したレイアウトを作る。
///
/// これを [BoardLayout.compile] すると、釘・入賞穴・チューリップ・スロット・
/// 回転体の座標が既存台と一致する（＝編集モードで既存台を再現できる）。
///
/// ブロック分割：
/// - `scatter` 散らし釘（グリッド 0,1／8×4）
/// - `slot`    スロット＋寄せ釘（グリッド 2,2／4×2。回転体はスロットから自動生成）
/// - `holeL` / `holeR` 入賞穴と誘導釘（グリッド 1,4 / 5,4／各 2×2）
/// - `tulip`   チューリップと命釘・道釘（グリッド 2,5／4×3）
BoardLayout buildPhase1Layout() {
  final pattern = Phase1StandardPattern();
  final cfg = BoardConfig.defaults();
  final allNails = pattern.buildNails(cfg);
  final holes = pattern.buildWinningHoles();
  final tulip = pattern.buildTulip(cfg);
  final slot = pattern.buildSlot()!;

  final scatter = Block(id: 'scatter', name: '散らし釘', cols: 8, rows: 4);
  final slotUnit = Block(id: 'slot', name: 'スロット', cols: 4, rows: 2);
  final holeL = Block(id: 'holeL', name: '入賞・左', cols: 2, rows: 2);
  final holeR = Block(id: 'holeR', name: '入賞・右', cols: 2, rows: 2);
  final tulipUnit = Block(id: 'tulip', name: 'チューリップ', cols: 4, rows: 3);

  final placements = <BlockPlacement>[
    BlockPlacement(blockId: 'scatter', col: 0, row: 1),
    BlockPlacement(blockId: 'slot', col: 2, row: 2),
    BlockPlacement(blockId: 'holeL', col: 1, row: 4),
    BlockPlacement(blockId: 'holeR', col: 5, row: 4),
    BlockPlacement(blockId: 'tulip', col: 2, row: 5),
  ];
  final oScatter = placements[0].origin;
  final oSlot = placements[1].origin;
  final oHoleL = placements[2].origin;
  final oHoleR = placements[3].origin;
  final oTulip = placements[4].origin;

  final hl = holes[0].pos;
  final hr = holes[1].pos;
  final sc = slot.center;

  for (final n in allNails) {
    if (n.pos.distanceTo(hl) < 9.5) {
      holeL.elements.add(_nail(n.pos - oHoleL));
    } else if (n.pos.distanceTo(hr) < 9.5) {
      holeR.elements.add(_nail(n.pos - oHoleR));
    } else if (n.pos.distanceTo(sc) < 10.0) {
      slotUnit.elements.add(_nail(n.pos - oSlot));
    } else if (n.pos.y >= 90.0) {
      tulipUnit.elements.add(_nail(n.pos - oTulip));
    } else {
      scatter.elements.add(_nail(n.pos - oScatter));
    }
  }

  slotUnit.elements
      .add(BlockElement(kind: ElementKind.slot, pos: slot.center - oSlot));
  tulipUnit.elements
      .add(BlockElement(kind: ElementKind.tulip, pos: tulip.base - oTulip));
  holeL.elements.add(BlockElement(
    kind: ElementKind.winningHole,
    pos: holes[0].pos - oHoleL,
    payout: holes[0].payout,
  ));
  holeR.elements.add(BlockElement(
    kind: ElementKind.winningHole,
    pos: holes[1].pos - oHoleR,
    payout: holes[1].payout,
  ));

  return BoardLayout(
    blocks: [scatter, slotUnit, holeL, holeR, tulipUnit],
    placements: placements,
  );
}

BlockElement _nail(Vec2 pos) => BlockElement(kind: ElementKind.nail, pos: pos);
