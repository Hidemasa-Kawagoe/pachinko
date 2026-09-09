import 'dart:math' as math;
import '../engine/vec2.dart';
import 'obstacles.dart';

/// 役物「チューリップ」。
///
/// - 玉が中央のセンサーに入ると入賞し、開閉状態が交互に切り替わる。
/// - 開いているときは左右の羽根が外側に開き、口が広くなって入りやすい。
/// - 閉じているときは羽根がほぼ垂直に立ち、口が狭くなる。
class Tulip {
  /// 台座（口）の中心位置。
  final Vec2 base;

  /// 羽根の長さ。
  final double petalLength;

  /// 開状態の羽根角度（垂直からの傾き, ラジアン）。
  final double openAngle;

  /// 閉状態の羽根角度（垂直からの傾き, ラジアン）。
  final double closedAngle;

  /// 賞球数（チューリップ入賞1回あたりの払い出し玉数）。Phase1 固定。
  final int payout;

  bool isOpen;

  /// 表示アニメーション用の補間値（0=閉, 1=開）。
  double animT;

  Tulip({
    required this.base,
    this.petalLength = 6.5,
    this.openAngle = 0.95,
    this.closedAngle = 0.18,
    this.payout = 15,
    this.isOpen = false,
  }) : animT = isOpen ? 1.0 : 0.0;

  double get _currentAngle {
    final t = animT;
    return closedAngle + (openAngle - closedAngle) * t;
  }

  /// 左右羽根の付け根。
  Vec2 get leftRoot => base + const Vec2(-2.0, 0.5);
  Vec2 get rightRoot => base + const Vec2(2.0, 0.5);

  /// 左羽根の先端。
  Vec2 get leftTip {
    final dir = const Vec2(0, -1).rotated(-_currentAngle);
    return leftRoot + dir * petalLength;
  }

  /// 右羽根の先端。
  Vec2 get rightTip {
    final dir = const Vec2(0, -1).rotated(_currentAngle);
    return rightRoot + dir * petalLength;
  }

  /// 羽根を線分障害物として返す（玉はこの上を転がる／弾かれる）。
  List<Segment> petalSegments() => [
        Segment(leftRoot, leftTip, restitution: 0.2),
        Segment(rightRoot, rightTip, restitution: 0.2),
      ];

  /// 入賞センサーの中心。
  Vec2 get sensorCenter => base + const Vec2(0, -0.5);

  /// 入賞センサーの半径。
  double get sensorRadius => 2.2;

  /// 開閉状態を反転する。
  void toggle() {
    isOpen = !isOpen;
  }

  /// アニメーション補間を進める。
  void stepAnim(double dt) {
    final target = isOpen ? 1.0 : 0.0;
    const speed = 6.0; // 1/6 秒でほぼ開閉
    if ((animT - target).abs() < 1e-3) {
      animT = target;
      return;
    }
    animT += (target - animT).clamp(-1.0, 1.0) * math.min(1.0, speed * dt);
  }
}
