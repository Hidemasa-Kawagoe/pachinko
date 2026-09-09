import '../engine/vec2.dart';

/// 釘（くぎ）。盤面に打たれた円形の静的障害物。
class Nail {
  Vec2 pos;
  final double radius;

  /// 分析タブから調整可能な「命釘（ヘソ釘）」グループかどうか。
  /// Phase1 ではチューリップ手前の釘のみ調整対象とする。
  final bool adjustable;

  Nail(this.pos, {this.radius = 0.7, this.adjustable = false});
}

/// 壁・レール・ガイドなどの線分障害物。
class Segment {
  final Vec2 a;
  final Vec2 b;

  /// 反発係数（0=吸収, 1=完全反発）。
  final double restitution;

  const Segment(this.a, this.b, {this.restitution = 0.35});
}

/// 入賞穴（ポケット）。玉が入ると賞球が払い出される。
/// Phase1 では賞球数・位置とも固定。
class WinningHole {
  final Vec2 pos;
  final double radius;

  /// 賞球数（入賞1回あたりの払い出し玉数）。Phase1 では固定値。
  final int payout;

  final String label;

  WinningHole({
    required this.pos,
    this.radius = 2.6,
    this.payout = 15,
    this.label = '入賞',
  });
}
