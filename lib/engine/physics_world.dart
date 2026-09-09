import 'dart:math' as math;

import '../models/ball.dart';
import '../models/board_pattern.dart';
import '../models/obstacles.dart';
import '../models/rotor.dart';
import '../models/slot_machine.dart';
import '../models/tulip.dart';
import 'vec2.dart';

/// パチンコ盤面の物理シミュレーション本体。
///
/// 固定タイムステップ（サブステップ）で積分し、玉と釘（円）・壁（線分）・
/// チューリップ羽根（線分）・センサー（円）の衝突を解決する。
/// 実機のような「バラつき」を出すため、釘との衝突ごとに微小なランダム回転を加える。
class PhysicsWorld {
  final BoardPattern pattern;
  BoardConfig config;

  late List<Segment> walls;
  late List<Nail> nails;
  late Tulip tulip;
  late List<WinningHole> holes;
  List<Rotor> rotors = [];
  SlotMachine? slot;

  final List<Ball> balls = [];
  final math.Random _rng;

  /// 30秒以上盤上に留まって強制排出された玉の数（＝詰まり配置の検出用。通常は 0）。
  int forcedDrains = 0;

  // --- 物理パラメータ ---
  double gravity = 240.0;

  /// 盤面内での最大速度。
  double fieldMaxSpeed = 235.0;

  /// 常時の速度上限（発射レーン内の高速移動も許容する）。
  double hardMaxSpeed = 380.0;

  double airDrag = 0.015;
  double nailRestitution = 0.30;
  double nailFriction = 0.14;

  static const double _subStep = 1.0 / 300.0;
  double _accumulator = 0.0;

  // --- イベントコールバック（統計はコントローラ側で集計）---
  void Function()? onFoul;
  void Function()? onOut;
  void Function(Tulip tulip)? onTulipIn;
  void Function(WinningHole hole)? onWinningHole;

  /// スロットが1回転を開始した（玉1個入賞）。
  void Function()? onSlotStart;

  /// スロットが停止して結果が確定した。
  void Function(SlotResult result)? onSlotResult;

  PhysicsWorld({
    required this.pattern,
    BoardConfig? config,
    int seed = 20250903,
  })  : config = config ?? BoardConfig.defaults(),
        _rng = math.Random(seed) {
    _rebuildAll();
  }

  void _rebuildAll() {
    walls = pattern.buildWalls();
    nails = pattern.buildNails(config);
    tulip = pattern.buildTulip(config);
    holes = pattern.buildWinningHoles();
    rotors = pattern.buildRotors();
    slot = pattern.buildSlot();
  }

  /// 調整パラメータを反映して釘配置のみ再生成する（玉・チューリップ状態は維持）。
  void applyConfig(BoardConfig newConfig) {
    config = newConfig.copy();
    nails = pattern.buildNails(config);
  }

  /// すべての玉を除去する（玉数リセット用）。
  void clearBalls() => balls.clear();

  /// 発射レーンに玉を1個投入する。[strength01] は 0.0〜1.0。
  ///
  /// 実機のように毎回わずかに勢い・位置がぶれるため、同じ強さでも
  /// 着地点はばらつく（統計が滑らかになる）。
  void spawnBall(double strength01) {
    final s = strength01.clamp(0.0, 1.0);
    final jitterSpeed = 1.0 + (_rng.nextDouble() - 0.5) * 0.06; // ±3%
    final speed = (190.0 + 150.0 * s) * jitterSpeed;
    final xJit = (_rng.nextDouble() - 0.5) * 0.9;
    final angJit = (_rng.nextDouble() - 0.5) * 0.05;
    balls.add(Ball(
      pos: pattern.launchPos + Vec2(xJit, 0),
      vel: (pattern.launchDir.normalized * speed).rotated(angJit),
      inLane: true,
    ));
  }

  int get ballCount => balls.length;

  /// フレーム更新。可変 [dt] を固定サブステップに分割して処理する。
  void step(double dt) {
    var frame = dt;
    if (frame.isNaN || frame <= 0) return;
    if (frame > 0.05) frame = 0.05; // 大きなフレーム落ちは丸める

    _accumulator += frame;
    var guard = 0;
    while (_accumulator >= _subStep && guard < 32) {
      _subStepUpdate(_subStep);
      _accumulator -= _subStep;
      guard++;
    }
    tulip.stepAnim(frame);

    // スロットの回転・演出を進め、停止結果が出たら通知する。
    final sl = slot;
    if (sl != null) {
      sl.step(frame);
      final res = sl.takePendingResult();
      if (res != null) onSlotResult?.call(res);
    }

    balls.removeWhere((b) => !b.alive);
  }

  void _subStepUpdate(double h) {
    final petals = tulip.petalSegments();
    final bladeSets = [for (final r in rotors) r.bladeSegments()];
    final sl = slot;
    // スロットは回転中・演出中は硬い円として玉をはじく（idle のときだけセンサー）。
    final slotSolid = sl != null && !sl.isIdle;

    for (final ball in balls) {
      if (!ball.alive) continue;
      ball.age += h;

      // 積分
      var v = ball.vel + Vec2(0, gravity * h);
      v = v * (1.0 - airDrag * h);

      final cap = ball.inLane ? hardMaxSpeed : fieldMaxSpeed;
      final sp = v.length;
      if (sp > cap) v = v * (cap / sp);
      ball.vel = v;
      ball.pos = ball.pos + ball.vel * h;

      // 衝突解決
      for (final s in walls) {
        _collideSegment(ball, s);
      }
      for (final s in petals) {
        _collideSegment(ball, s);
      }
      for (final n in nails) {
        _collideNail(ball, n);
      }
      for (var ri = 0; ri < rotors.length; ri++) {
        _collideRotor(ball, rotors[ri], bladeSets[ri]);
      }
      if (slotSolid) {
        _collideSolidCircle(ball, sl.center, sl.sensorRadius, 0.3);
      }

      // 詰まり防止：ほぼ静止したら横方向の揺らぎ＋わずかに下向きへ押す
      if (ball.vel.lengthSquared < 4.0) {
        ball.vel = ball.vel + Vec2((_rng.nextDouble() - 0.5) * 5.0, 0.9);
      }
    }

    _resolveBallPairs();
    for (final r in rotors) {
      r.step(h);
    }
    _checkSensorsAndBounds();
  }

  /// 玉と「動かない硬い円」の衝突（回転中のスロット口など）。
  void _collideSolidCircle(
      Ball ball, Vec2 center, double radius, double restitution) {
    final d = ball.pos - center;
    final dist = d.length;
    final minDist = ball.radius + radius;
    if (dist >= minDist) return;

    final n = dist < 1e-6 ? const Vec2(0, -1) : d / dist;
    ball.pos = center + n * minDist;

    final vn = ball.vel.dot(n);
    if (vn < 0) {
      var vNew = ball.vel - n * ((1.0 + restitution) * vn);
      final tang = vNew - n * vNew.dot(n);
      vNew = vNew - tang * 0.1;
      ball.vel = vNew.rotated((_rng.nextDouble() - 0.5) * 0.2);
    }
  }

  /// 玉と回転体（ハブ円＋各羽根の線分）の衝突。
  /// 羽根は回転しているため、接触点の表面速度を考慮した相対速度で反射し、
  /// 反作用として回転体へ角力積を与える（＝玉が回転体を回す）。
  void _collideRotor(Ball ball, Rotor rt, List<(Vec2, Vec2)> blades) {
    final rough = ball.pos - rt.center;
    if (rough.length > rt.tipRadius + ball.radius + 1.0) return;

    void resolve(Vec2 cp, double restitution) {
      final d = ball.pos - cp;
      final dist = d.length;
      final n = dist < 1e-6 ? (ball.pos - rt.center).normalized : d / dist;
      ball.pos = cp + n * ball.radius;

      final vsurf = rt.surfaceVelocityAt(cp);
      final vn = (ball.vel - vsurf).dot(n);
      if (vn >= 0) return;

      final rC = cp - rt.center;
      final lever = rC.x * n.y - rC.y * n.x; // cross(r, n) の z 成分
      // 玉の質量（5.4g）と回転体の慣性モーメントを考慮した連成インパルス。
      final invMass = 1.0 / ball.mass;
      final jn = -(1.0 + restitution) *
          vn /
          (invMass + (lever * lever) / rt.inertia);
      ball.vel = ball.vel + n * (jn * invMass);
      rt.omega += jn * lever / rt.inertia;
      // 予測不能なはじき方にするための小さなランダム回転
      ball.vel = ball.vel.rotated((_rng.nextDouble() - 0.5) * 0.4);
    }

    // ハブ（中心の円）
    final distHub = rough.length;
    if (distHub < ball.radius + rt.hubRadius) {
      final n = distHub < 1e-6 ? const Vec2(0, -1) : rough / distHub;
      resolve(rt.center + n * rt.hubRadius, 0.2);
    }

    // 各羽根
    for (final (a, b) in blades) {
      final cp = _closestPointOnSegment(ball.pos, a, b);
      if ((ball.pos - cp).length < ball.radius) {
        resolve(cp, 0.12);
      }
    }

    // 回転体の上で止まりかけたら、回転体を軽く回して玉を落とす（詰まり防止）
    if (ball.vel.lengthSquared < 6.0 &&
        rt.omega.abs() < 0.5 &&
        (ball.pos - rt.center).length < rt.tipRadius + ball.radius + 0.3) {
      rt.omega += (_rng.nextDouble() - 0.5) * 3.0;
      ball.vel = ball.vel + Vec2((_rng.nextDouble() - 0.5) * 6.0, 1.5);
    }
  }

  void _collideNail(Ball ball, Nail nail) {
    final d = ball.pos - nail.pos;
    final dist = d.length;
    final minDist = ball.radius + nail.radius;
    if (dist >= minDist) return;

    final n = dist < 1e-6 ? const Vec2(0, -1) : d / dist;
    ball.pos = nail.pos + n * minDist;

    final vn = ball.vel.dot(n);
    if (vn < 0) {
      var vNew = ball.vel - n * ((1.0 + nailRestitution) * vn);
      final tang = vNew - n * vNew.dot(n);
      vNew = vNew - tang * nailFriction;
      // 実機の「命釘のバラけ」を再現するランダム回転（大きめにして挙動を確率的に）
      final jitter = (_rng.nextDouble() - 0.5) * 0.34;
      ball.vel = vNew.rotated(jitter);
    }
  }

  void _collideSegment(Ball ball, Segment s) {
    final cp = _closestPointOnSegment(ball.pos, s.a, s.b);
    final d = ball.pos - cp;
    final dist = d.length;
    if (dist >= ball.radius) return;

    final Vec2 n;
    if (dist < 1e-6) {
      final mid = (s.a + s.b) * 0.5;
      n = (ball.pos - mid).normalized;
    } else {
      n = d / dist;
    }
    ball.pos = cp + n * ball.radius;

    final vn = ball.vel.dot(n);
    if (vn < 0) {
      var vNew = ball.vel - n * ((1.0 + s.restitution) * vn);
      final tang = vNew - n * vNew.dot(n);
      vNew = vNew - tang * 0.06; // レールの摩擦は軽め
      ball.vel = vNew;
    }
  }

  void _resolveBallPairs() {
    for (var i = 0; i < balls.length; i++) {
      final a = balls[i];
      if (!a.alive) continue;
      for (var j = i + 1; j < balls.length; j++) {
        final b = balls[j];
        if (!b.alive) continue;
        final d = b.pos - a.pos;
        final dist = d.length;
        final minDist = a.radius + b.radius;
        if (dist >= minDist || dist < 1e-6) continue;

        final n = d / dist;
        final overlap = minDist - dist;
        a.pos = a.pos - n * (overlap * 0.5);
        b.pos = b.pos + n * (overlap * 0.5);

        final rv = b.vel - a.vel;
        final vn = rv.dot(n);
        if (vn < 0) {
          // 玉どうしは同質量（5.4g）なので、結果は質量値に依存しない。
          const e = 0.18;
          final jImp = -(1.0 + e) * vn / 2.0;
          a.vel = a.vel - n * jImp;
          b.vel = b.vel + n * jImp;
        }
      }
    }
  }

  void _checkSensorsAndBounds() {
    for (final ball in balls) {
      if (!ball.alive) continue;

      // 発射レーンから出て盤面へ入ったか判定（レーン左端 x=90 より左へ出たら）
      if (ball.inLane && ball.pos.x < 88) {
        ball.inLane = false;
      }

      // ファウル：発射が弱く／強すぎてレーンを逆流し、盤面へ入らず戻ってきた
      if (ball.vel.y > 0 &&
          ball.pos.y > 126 &&
          (ball.inLane || ball.pos.x > 89)) {
        ball.alive = false;
        onFoul?.call();
        continue;
      }

      // スロット入賞センサー（idle のときだけ受け付け → 1回転開始）
      final sl = slot;
      if (sl != null &&
          sl.isIdle &&
          ball.pos.distanceTo(sl.center) < sl.sensorRadius + ball.radius * 0.5) {
        ball.alive = false;
        sl.startSpin();
        onSlotStart?.call();
        continue;
      }

      // チューリップ入賞センサー
      if (ball.pos.distanceTo(tulip.sensorCenter) < tulip.sensorRadius) {
        ball.alive = false;
        tulip.toggle();
        onTulipIn?.call(tulip);
        continue;
      }

      // 入賞穴（誘導釘の喉元へ来た時点で取り込む。玉半径ぶん広げて
      // 「弧と穴の間で玉が留まる」状態になる前に入賞として処理する）
      var caught = false;
      for (final hole in holes) {
        if (ball.pos.distanceTo(hole.pos) < hole.radius + ball.radius * 0.5) {
          ball.alive = false;
          onWinningHole?.call(hole);
          caught = true;
          break;
        }
      }
      if (caught) continue;

      // アウト（盤外）
      if (ball.pos.y > 137 || ball.pos.x < 3.0 || ball.pos.x > 99.5) {
        ball.alive = false;
        onOut?.call();
        continue;
      }
      // 長時間の詰まり玉の強制排出（本来は起きてはいけない安全網）
      if (ball.age > 30.0) {
        ball.alive = false;
        forcedDrains++;
        onOut?.call();
        continue;
      }
    }
  }

  static Vec2 _closestPointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final denom = ab.lengthSquared;
    if (denom < 1e-9) return a;
    var t = (p - a).dot(ab) / denom;
    t = t.clamp(0.0, 1.0);
    return a + ab * t;
  }
}
