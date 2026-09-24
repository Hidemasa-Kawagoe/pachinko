import '../engine/vec2.dart';
import '../models/obstacles.dart';
import '../models/rotor.dart';
import '../models/slot_machine.dart';
import '../models/tulip.dart';
import 'block.dart';

/// スロット要素から生成する左右の回転体のオフセット（スロット中心からの相対）。
/// 既存台と同じく「スロットの左右・少し下」に半分サイズの回転体を置く。
const Vec2 kRotorOffsetLeft = Vec2(-18, 11);
const Vec2 kRotorOffsetRight = Vec2(18, 11);

/// ブロック配置をコンパイルして得られる、物理世界がそのまま使える障害物一式。
class CompiledLayout {
  final List<Nail> nails;
  final List<WinningHole> holes;
  final List<Tulip> tulips;
  final List<SlotMachine> slots;
  final List<Rotor> rotors;

  const CompiledLayout({
    required this.nails,
    required this.holes,
    required this.tulips,
    required this.slots,
    required this.rotors,
  });
}

/// 台のレイアウト全体。ブロックのライブラリと、その配置リスト。
class BoardLayout {
  final List<Block> blocks;
  final List<BlockPlacement> placements;

  BoardLayout({List<Block>? blocks, List<BlockPlacement>? placements})
      : blocks = blocks ?? <Block>[],
        placements = placements ?? <BlockPlacement>[];

  Block? blockById(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  BoardLayout copy() => BoardLayout(
        blocks: blocks.map((b) => b.copy()).toList(),
        placements: placements.map((p) => p.copy()).toList(),
      );

  /// 配置を展開し、絶対座標の障害物へ変換する。
  /// スロット要素は「スロット本体＋左右2基の回転体」を生成する。
  CompiledLayout compile() {
    final nails = <Nail>[];
    final holes = <WinningHole>[];
    final tulips = <Tulip>[];
    final slots = <SlotMachine>[];
    final rotors = <Rotor>[];

    for (final p in placements) {
      final b = blockById(p.blockId);
      if (b == null) continue;
      final o = p.origin;
      for (final e in b.elements) {
        final abs = o + e.pos;
        switch (e.kind) {
          case ElementKind.nail:
            nails.add(Nail(abs));
            break;
          case ElementKind.winningHole:
            holes.add(WinningHole(
              pos: abs,
              radius: 2.2,
              payout: e.payout,
              label: '入賞',
            ));
            break;
          case ElementKind.tulip:
            tulips.add(Tulip(base: abs, isOpen: false));
            break;
          case ElementKind.slot:
            slots.add(SlotMachine(center: abs, sensorRadius: 2.6));
            rotors.add(Rotor(
              center: abs + kRotorOffsetLeft,
              hubRadius: 1.2,
              tipRadius: 2.8,
              blades: 6,
              massGrams: 6.0,
            ));
            rotors.add(Rotor(
              center: abs + kRotorOffsetRight,
              hubRadius: 1.2,
              tipRadius: 2.8,
              blades: 6,
              massGrams: 6.0,
            ));
            break;
        }
      }
    }

    return CompiledLayout(
      nails: nails,
      holes: holes,
      tulips: tulips,
      slots: slots,
      rotors: rotors,
    );
  }

  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'placements': placements.map((p) => p.toJson()).toList(),
      };

  factory BoardLayout.fromJson(Map<String, dynamic> j) => BoardLayout(
        blocks: (j['blocks'] as List)
            .map((b) => Block.fromJson(b as Map<String, dynamic>))
            .toList(),
        placements: (j['placements'] as List)
            .map((p) => BlockPlacement.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
