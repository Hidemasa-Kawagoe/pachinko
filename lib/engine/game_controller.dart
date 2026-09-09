import 'package:flutter/foundation.dart';

import '../models/board_pattern.dart';
import '../models/slot_machine.dart';
import 'physics_world.dart';

/// 統計情報。
class GameStats {
  int launched = 0; // 発射数
  int tulipIn = 0; // チューリップ入賞数
  int winning = 0; // 入賞穴の入賞数
  int foul = 0; // ファウル（戻り玉）数
  int out = 0; // アウト数
  int payoutTotal = 0; // 払い出し賞球の累計

  int slotPlays = 0; // スロット入賞数（回転を開始した回数）
  int slotWins = 0; // スロット当たり（3つ揃い、7以外）
  int slotJackpots = 0; // スロット大当たり（7揃い）

  /// チューリップ入賞率（発射数に対する割合）。
  double get tulipRate => launched == 0 ? 0.0 : tulipIn / launched;

  /// スロット当たり率（大当たり含む／スロット入賞数に対する割合）。
  double get slotHitRate =>
      slotPlays == 0 ? 0.0 : (slotWins + slotJackpots) / slotPlays;

  /// 盤面に到達した玉（発射数 − ファウル）。
  int get validLaunched => launched - foul;

  void reset() {
    launched = 0;
    tulipIn = 0;
    winning = 0;
    foul = 0;
    out = 0;
    payoutTotal = 0;
    slotPlays = 0;
    slotWins = 0;
    slotJackpots = 0;
  }
}

/// スロットの賞球（Phase1 固定値）。
const int kSlotWinPayout = 20; // 当たり
const int kSlotJackpotPayout = 100; // 大当たり

/// ゲーム全体のコントローラ。物理世界・玉数・統計・発射を管理する。
class GameController extends ChangeNotifier {
  GameController({BoardPattern? pattern})
      : world = PhysicsWorld(pattern: pattern ?? BoardPattern.phase1Standard) {
    _wireCallbacks();
    remainingBalls = initialBallCount;
  }

  final PhysicsWorld world;
  final GameStats stats = GameStats();

  /// 初期弾数（この値だけを設定し、何度でもリセット可能）。
  int initialBallCount = 300;

  /// 現在の持ち玉。
  int remainingBalls = 300;

  /// 発射の強さ（0〜100）。中程度が最もチューリップへ届きやすい。
  double strength = 56;

  /// 自動発射中かどうか。
  bool autoLaunching = false;

  /// 自動発射の間隔（秒）。仕様：0.5秒ごと。
  static const double autoInterval = 0.5;
  double _autoAccum = 0.0;

  double get strength01 => (strength / 100.0).clamp(0.0, 1.0);

  BoardConfig get config => world.config;

  void _wireCallbacks() {
    world.onFoul = () {
      stats.foul++;
      // ファウル玉は戻ってくるため持ち玉に返却する
      remainingBalls++;
    };
    world.onOut = () {
      stats.out++;
    };
    world.onTulipIn = (tulip) {
      stats.tulipIn++;
      stats.payoutTotal += tulip.payout;
      remainingBalls += tulip.payout;
    };
    world.onWinningHole = (hole) {
      stats.winning++;
      stats.payoutTotal += hole.payout;
      remainingBalls += hole.payout;
    };
    world.onSlotStart = () {
      stats.slotPlays++;
    };
    world.onSlotResult = (SlotResult res) {
      if (res.isJackpot) {
        stats.slotJackpots++;
        stats.payoutTotal += kSlotJackpotPayout;
        remainingBalls += kSlotJackpotPayout;
      } else if (res.matched) {
        stats.slotWins++;
        stats.payoutTotal += kSlotWinPayout;
        remainingBalls += kSlotWinPayout;
      }
    };
  }

  // --- 発射 ---

  /// 手動発射：現在の強さで1個発射する。
  void manualLaunch() {
    if (remainingBalls <= 0) return;
    remainingBalls--;
    stats.launched++;
    world.spawnBall(strength01);
    notifyListeners();
  }

  void _autoLaunchOne() {
    if (remainingBalls <= 0) {
      autoLaunching = false;
      return;
    }
    remainingBalls--;
    stats.launched++;
    world.spawnBall(strength01);
  }

  void toggleAuto() {
    autoLaunching = !autoLaunching;
    _autoAccum = 0.0;
    notifyListeners();
  }

  void setStrength(double v) {
    strength = v.clamp(0.0, 100.0);
    notifyListeners();
  }

  // --- 調整（分析タブ）---

  void updateConfig(BoardConfig newConfig) {
    world.applyConfig(newConfig);
    notifyListeners();
  }

  void resetConfigToDefault() {
    world.applyConfig(BoardConfig.defaults());
    notifyListeners();
  }

  // --- 玉数リセット ---

  void setInitialBallCount(int count) {
    initialBallCount = count.clamp(1, 100000);
    notifyListeners();
  }

  /// 持ち玉と統計を初期状態へ戻す（盤上の玉も消す）。何度でも実行可能。
  void resetGame() {
    world.clearBalls();
    stats.reset();
    remainingBalls = initialBallCount;
    autoLaunching = false;
    _autoAccum = 0.0;
    notifyListeners();
  }

  /// 統計のみリセット（持ち玉はそのまま）。
  void resetStatsOnly() {
    stats.reset();
    notifyListeners();
  }

  // --- フレーム更新（UI の Ticker から毎フレーム呼ばれる）---

  void tick(double dt) {
    if (autoLaunching) {
      _autoAccum += dt;
      while (_autoAccum >= autoInterval) {
        _autoAccum -= autoInterval;
        _autoLaunchOne();
      }
    }
    world.step(dt);
    notifyListeners();
  }
}
