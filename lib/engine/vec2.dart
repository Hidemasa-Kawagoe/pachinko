import 'dart:math' as math;

/// 2次元ベクトル（イミュータブル）。物理演算全体で使用する軽量な数値型。
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  double dot(Vec2 o) => x * o.x + y * o.y;

  Vec2 get normalized {
    final len = length;
    if (len < 1e-9) return Vec2.zero;
    return Vec2(x / len, y / len);
  }

  double distanceTo(Vec2 o) => (this - o).length;

  /// 原点まわりに [radians] だけ回転させたベクトルを返す。
  Vec2 rotated(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
