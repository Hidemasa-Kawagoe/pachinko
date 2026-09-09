import 'dart:math' as math;
import '../engine/vec2.dart';

/// 回転体（風車 / 水車）。
///
/// - ハブ（中心の円）から放射状に羽根が伸び、羽根と羽根の間が「玉1個分のポケット」。
/// - モーターは無く、玉の衝突で受ける角力積と角減衰だけで回る。
/// - 玉はポケットに乗って運ばれ、回転体の下部で自然にこぼれ落ちるため、
///   落下軌道が予測しにくくなる。
class Rotor {
  final Vec2 center;

  /// ハブ半径（玉半径の約1.5倍）。
  final double hubRadius;

  /// 羽根の先端までの半径。
  final double tipRadius;

  /// 羽根の枚数（＝ポケット数）。
  final int blades;

  /// 回転体の質量（グラム）。玉（5.4g）との運動量のやり取りの基準。
  final double massGrams;

  /// 慣性モーメント（g·unit²）。既定では一様円板 I = ½·M·R² で算出。
  /// 大きいほど回りにくく、止まりにくい。
  final double inertia;

  /// 角減衰（1/秒）。衝突が無いときに徐々に停止する。
  final double damping;

  /// 現在の回転角（ラジアン）。
  double angle;

  /// 角速度（ラジアン/秒、反時計回りが正）。
  double omega;

  Rotor({
    required this.center,
    this.hubRadius = 2.4,
    this.tipRadius = 5.6,
    this.blades = 6,
    this.massGrams = 12.0,
    double? inertia,
    this.damping = 0.7,
    this.angle = 0.0,
    this.omega = 0.0,
  }) : inertia = inertia ?? 0.5 * massGrams * tipRadius * tipRadius;

  /// 角速度の上限（暴走防止）。
  static const double maxOmega = 18.0;

  /// 各羽根の線分（ハブ外周 → 先端）。現在の [angle] を反映する。
  List<(Vec2, Vec2)> bladeSegments() {
    final res = <(Vec2, Vec2)>[];
    for (var i = 0; i < blades; i++) {
      final a = angle + i * 2 * math.pi / blades;
      final dir = Vec2(math.cos(a), math.sin(a));
      res.add((center + dir * hubRadius, center + dir * tipRadius));
    }
    return res;
  }

  /// 点 [p] における回転体表面の速度（ω × r）。
  Vec2 surfaceVelocityAt(Vec2 p) {
    final r = p - center;
    return Vec2(-omega * r.y, omega * r.x);
  }

  /// 角度と角速度を1サブステップぶん進める。
  void step(double h) {
    omega = omega.clamp(-maxOmega, maxOmega);
    angle += omega * h;
    omega *= (1.0 - damping * h).clamp(0.0, 1.0);
    const twoPi = math.pi * 2;
    angle %= twoPi;
    if (angle < 0) angle += twoPi;
  }
}
