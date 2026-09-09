import 'dart:math' as math;
import '../engine/vec2.dart';

/// スロットの停止結果。
class SlotResult {
  /// 3リールの停止柄インデックス（0..9）。
  final List<int> symbols;

  /// 3つ揃い（当たり）。
  final bool matched;

  /// 7揃い（大当たり）。
  final bool isJackpot;

  const SlotResult({
    required this.symbols,
    required this.matched,
    required this.isJackpot,
  });
}

enum SlotPhase { idle, spinning }

/// 台中央のギミック「スリーセブンスロット」。
///
/// - 玉が1個センサーに入ると1回転を開始する（回転中・演出中は受け付けない）。
/// - 各リールは 1〜9 の数字＋コイン（0 の代わり）の計10柄が順に並ぶ。
/// - 3つのリールが回り、**3秒以内に**順番に自動停止する。
/// - 3つ揃い＝当たり（玉20加算）。7揃い＝大当たり（玉100加算＋点滅演出）。
class SlotMachine {
  final Vec2 center;
  final double sensorRadius;

  /// 柄数（1〜9 と コイン）。
  static const int symbolCount = 10;

  /// 「7」の柄インデックス（1→0, 2→1, … 7→6, … 9→8, コイン→9）。
  static const int sevenIndex = 6;

  /// コインの柄インデックス（0 の代わり）。
  static const int coinIndex = 9;

  /// 全リールが停止するまでの上限（秒）。
  static const double maxSpinSeconds = 3.0;

  static const double _blinkDuration = 2.5;

  SlotPhase phase = SlotPhase.idle;

  /// 各リールの連続位置（柄単位、0〜10 で循環）。描画に使う。
  final List<double> reelPos = [0, 0, 0];
  final List<double> _reelSpeed = [0, 0, 0];
  final List<int> _reelTarget = [0, 0, 0];
  final List<double> _reelStopAt = [0, 0, 0];
  final List<bool> reelSpinning = [false, false, false];

  double _elapsed = 0;

  /// 点滅演出の残り時間（>0 の間は演出中）。
  double blinkTimer = 0;

  SlotResult? _pending;
  final math.Random _rng;

  SlotMachine({
    required this.center,
    this.sensorRadius = 2.6,
    int seed = 777,
  }) : _rng = math.Random(seed);

  /// 玉を受け付けられる（＝回転も演出もしていない）か。
  bool get isIdle => phase == SlotPhase.idle && blinkTimer <= 0;
  bool get isSpinning => phase == SlotPhase.spinning;
  bool get isBlinking => blinkTimer > 0;

  /// 各リールに現在表示されている柄（中央）。
  List<int> get visibleSymbols =>
      [for (final p in reelPos) p.floor() % symbolCount];

  /// 回転を開始する。受け付け不可なら何もしない。
  void startSpin() {
    if (!isIdle) return;
    phase = SlotPhase.spinning;
    _elapsed = 0;
    _pending = null;
    for (var i = 0; i < 3; i++) {
      reelSpinning[i] = true;
      _reelSpeed[i] = 20 + _rng.nextDouble() * 8; // 柄/秒（約2回転/秒）
      _reelTarget[i] = _rng.nextInt(symbolCount);
      // 0.8s / 1.6s / 2.4s あたりで順に停止（±0.2s、最大 2.6s < 3s）
      _reelStopAt[i] = 0.8 + i * 0.8 + _rng.nextDouble() * 0.2;
    }
  }

  /// 1フレーム進める。
  void step(double dt) {
    if (blinkTimer > 0) {
      blinkTimer = math.max(0.0, blinkTimer - dt);
    }
    if (phase != SlotPhase.spinning) return;

    _elapsed += dt;
    for (var i = 0; i < 3; i++) {
      if (!reelSpinning[i]) continue;
      if (_elapsed >= _reelStopAt[i]) {
        reelSpinning[i] = false;
        reelPos[i] = _reelTarget[i].toDouble();
      } else {
        reelPos[i] = (reelPos[i] + _reelSpeed[i] * dt) % symbolCount;
      }
    }

    if (!reelSpinning[0] && !reelSpinning[1] && !reelSpinning[2]) {
      final res = evaluate(_reelTarget);
      _pending = res;
      if (res.isJackpot) blinkTimer = _blinkDuration;
      phase = SlotPhase.idle;
    }
  }

  /// 停止結果を1回だけ取り出す（未確定なら null）。
  SlotResult? takePendingResult() {
    final r = _pending;
    _pending = null;
    return r;
  }

  /// 3柄から結果を判定する純関数。
  static SlotResult evaluate(List<int> s) {
    final matched = s[0] == s[1] && s[1] == s[2];
    return SlotResult(
      symbols: List<int>.of(s),
      matched: matched,
      isJackpot: matched && s[0] == sevenIndex,
    );
  }

  /// 柄インデックス → 表示ラベル（数字文字列。コインは null）。
  static String? digitLabel(int idx) =>
      (idx % symbolCount) == coinIndex ? null : '${(idx % symbolCount) + 1}';
}
