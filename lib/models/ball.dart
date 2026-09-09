import '../engine/vec2.dart';

/// パチンコ玉の質量（グラム）。実機の遊技球は 5.4g（直径11mm・鋼球）。
const double kBallMassGrams = 5.4;

/// パチンコ玉。動的な物理ボディ。
class Ball {
  Vec2 pos;
  Vec2 vel;
  final double radius;

  /// 質量（グラム）。自由落下・釘/壁との反射は質量に依存しない（＝軌道は不変）が、
  /// 可動物（回転体）との運動量のやり取りに効く。
  final double mass;

  /// 発射レーン内を上昇中かどうか（ファウル判定に使用）。
  bool inLane;

  /// 生存フラグ。false になった玉は次フレームで除去される。
  bool alive = true;

  /// 盤面に出てからの経過秒数（詰まり玉の強制排出に使用）。
  double age = 0;

  Ball({
    required this.pos,
    required this.vel,
    this.radius = 1.6,
    this.mass = kBallMassGrams,
    this.inLane = true,
  });
}
