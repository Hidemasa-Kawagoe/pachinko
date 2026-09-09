import 'package:flutter_test/flutter_test.dart';
import 'package:pachinko_sim/engine/game_controller.dart';
import 'package:pachinko_sim/engine/physics_world.dart';
import 'package:pachinko_sim/engine/vec2.dart';
import 'package:pachinko_sim/models/ball.dart';
import 'package:pachinko_sim/models/board_pattern.dart';
import 'package:pachinko_sim/models/rotor.dart';
import 'package:pachinko_sim/models/slot_machine.dart';

/// 物理世界を [seconds] 秒ぶん、1/60 刻みで進める。
void advance(void Function(double) tick, double seconds) {
  const dt = 1 / 60;
  for (var i = 0; i < (seconds / dt).round(); i++) {
    tick(dt);
  }
}

/// [launches] 発を [gapSeconds] 間隔で発射し、すべて排出されるまで進める。
GameController runSession({
  required int initialBalls,
  required double strength,
  required int launches,
  double gapSeconds = 0.15,
  BoardConfig? config,
}) {
  final c = GameController();
  c.setInitialBallCount(initialBalls);
  c.resetGame();
  if (config != null) c.updateConfig(config);
  c.setStrength(strength);
  for (var i = 0; i < launches; i++) {
    c.manualLaunch();
    advance(c.tick, gapSeconds);
  }
  advance(c.tick, 60);
  return c;
}

void main() {
  test('弱い発射はファウルになり、持ち玉が返却される', () {
    final c = GameController()
      ..setInitialBallCount(50)
      ..resetGame()
      ..setStrength(2);
    c.manualLaunch();
    expect(c.remainingBalls, 49);
    advance(c.tick, 12);
    expect(c.stats.foul, greaterThanOrEqualTo(1));
    expect(c.remainingBalls, 50, reason: 'ファウル玉は持ち玉へ返却される');
    expect(c.world.ballCount, 0);
  });

  test('発射した玉はすべて処理され、収支（数）が保存される（NaN なし）', () {
    final c = runSession(
      initialBalls: 500,
      strength: 56,
      launches: 60,
    );

    for (final b in c.world.balls) {
      expect(b.pos.x.isFinite && b.pos.y.isFinite, isTrue);
    }
    expect(c.world.ballCount, 0, reason: '盤上に残り続ける玉（詰まり）は無い');

    final s = c.stats;
    expect(s.launched, 60);
    expect(s.foul + s.out + s.tulipIn + s.winning + s.slotPlays, 60,
        reason: '発射数 = ファウル + アウト + チューリップ + 入賞穴 + スロット入賞');
  });

  test('中程度の強さでチューリップ入賞が発生し、賞球で持ち玉が増える', () {
    final c = runSession(
      initialBalls: 800,
      strength: 56,
      launches: 200,
      config: BoardConfig()
        ..lifeNailGap = 12.0
        ..lifeNailHeight = 11.0,
    );
    expect(c.stats.tulipIn, greaterThan(0));
    expect(c.stats.payoutTotal, greaterThan(0));
    // 発射数 200 に対して賞球（チューリップ15＋入賞穴10）が入るため持ち玉は増える
    expect(c.remainingBalls, greaterThan(800 - 200));
  });

  test('命釘を広げるとチューリップ入賞率が上がる傾向がある', () {
    final narrow = runSession(
      initialBalls: 1500,
      strength: 56,
      launches: 400,
      config: BoardConfig()..lifeNailGap = BoardConfig.gapMin,
    );
    final wide = runSession(
      initialBalls: 1500,
      strength: 56,
      launches: 400,
      config: BoardConfig()..lifeNailGap = BoardConfig.gapMax,
    );
    expect(wide.stats.tulipIn, greaterThan(narrow.stats.tulipIn),
        reason: '命釘の間隔が広いほどチューリップへ入りやすい '
            '(narrow=${narrow.stats.tulipIn}, wide=${wide.stats.tulipIn})');
  });

  test('resetGame で持ち玉と統計が初期化される', () {
    final c = runSession(
      initialBalls: 100,
      strength: 56,
      launches: 10,
    );
    c.resetGame();
    expect(c.remainingBalls, 100);
    expect(c.stats.launched, 0);
    expect(c.stats.tulipIn, 0);
    expect(c.world.ballCount, 0);
  });

  test('自動発射は約0.5秒間隔で1発ずつ発射する', () {
    final c = GameController()
      ..setInitialBallCount(100)
      ..resetGame()
      ..setStrength(56);
    c.toggleAuto();
    advance(c.tick, 2.05); // 約4発ぶん
    expect(c.stats.launched, inInclusiveRange(3, 5));
    c.toggleAuto();
    final afterStop = c.stats.launched;
    advance(c.tick, 2.0);
    expect(c.stats.launched, afterStop, reason: '停止後は発射されない');
  });

  test('持ち玉が0になると発射できない', () {
    final c = GameController()
      ..setInitialBallCount(3)
      ..resetGame()
      ..setStrength(56);
    for (var i = 0; i < 10; i++) {
      c.manualLaunch();
    }
    expect(c.stats.launched, lessThanOrEqualTo(3));
    expect(c.remainingBalls, greaterThanOrEqualTo(0));
  });

  test('チューリップは玉が入るたびに開閉が切り替わる', () {
    final w = PhysicsWorld(pattern: BoardPattern.phase1Standard);
    expect(w.tulip.isOpen, isFalse);
    w.tulip.toggle();
    expect(w.tulip.isOpen, isTrue);
    w.tulip.toggle();
    expect(w.tulip.isOpen, isFalse);
  });

  test('玉が盤上で詰まらない（入賞穴・スロット・回転体・屋根の端でも留まらない）', () {
    for (final strength in [30.0, 45.0, 56.0, 70.0, 90.0]) {
      final c = GameController()
        ..setInitialBallCount(4000)
        ..resetGame();
      c.setStrength(strength);

      for (var i = 0; i < 300; i++) {
        c.manualLaunch();
        advance(c.tick, 0.12);
      }
      // 発射終了から少し待った時点で、盤上にはほとんど玉が残っていないはず。
      advance(c.tick, 12);
      expect(c.world.ballCount, lessThan(6),
          reason: 'strength=$strength: 発射終了+12秒でも玉が滞留（詰まり配置あり）');

      advance(c.tick, 60);
      expect(c.world.ballCount, 0,
          reason: 'strength=$strength で玉が盤上に残った');
      // 30秒の安全網に頼らず処理できている（＝落ちなくなる配置が無い）。
      expect(c.world.forcedDrains, 0,
          reason: 'strength=$strength: 強制排出された玉がある（どこかで詰まっている）');

      final s = c.stats;
      expect(s.foul + s.out + s.tulipIn + s.winning + s.slotPlays, s.launched,
          reason: '発射数 = ファウル + アウト + チューリップ + 入賞穴 + スロット入賞');
    }
  });

  test('左右2基の回転体は玉の衝突で回転する（従来の半分サイズ）', () {
    final w = PhysicsWorld(pattern: BoardPattern.phase1Standard);
    expect(w.rotors.length, 2);
    expect(w.rotors[0].center, Phase1StandardPattern.rotorLeftCenter);
    expect(w.rotors[1].center, Phase1StandardPattern.rotorRightCenter);
    expect(w.rotors[0].tipRadius, Phase1StandardPattern.rotorTipRadius);
    expect(Phase1StandardPattern.rotorTipRadius, 2.8); // 5.6 の半分

    var maxOmega = 0.0;
    for (var i = 0; i < 120; i++) {
      w.spawnBall(0.5 + (i % 5) * 0.08);
      for (var k = 0; k < 60 * 8; k++) {
        w.step(1 / 60);
        for (final r in w.rotors) {
          if (r.omega.abs() > maxOmega) maxOmega = r.omega.abs();
        }
      }
    }
    expect(maxOmega, greaterThan(2.0), reason: '回転体が回っていない');
    expect(maxOmega, lessThanOrEqualTo(Rotor.maxOmega + 0.01));
  });

  test('回転体は衝突が無ければ減衰して止まる', () {
    final r = Rotor(center: const Vec2(50, 56), omega: 10.0);
    for (var k = 0; k < 60 * 20; k++) {
      r.step(1 / 60);
    }
    expect(r.omega.abs(), lessThan(0.05));
  });

  test('玉の質量は 5.4g（発射された玉にも設定される）', () {
    expect(kBallMassGrams, 5.4);
    expect(Ball(pos: Vec2.zero, vel: Vec2.zero).mass, 5.4);

    final w = PhysicsWorld(pattern: BoardPattern.phase1Standard);
    w.spawnBall(0.56);
    expect(w.balls.single.mass, 5.4);
  });

  test('自由落下・釘との反射は質量に依存しない（同一シードなら同一軌道）', () {
    // 質量だけ変えても、釘・壁のみとの衝突なら軌道は変わらない。
    List<Vec2> run(double mass) {
      final w = PhysicsWorld(pattern: BoardPattern.phase1Standard, seed: 42);
      // 回転体（中央）に触れない左下から落として、壁・釘のみと衝突させる。
      final b = Ball(
        pos: const Vec2(14, 98),
        vel: const Vec2(2, 0),
        mass: mass,
      );
      b.inLane = false;
      w.balls.add(b);
      final path = <Vec2>[];
      for (var k = 0; k < 180 && w.balls.isNotEmpty; k++) {
        w.step(1 / 60);
        if (w.balls.isNotEmpty) path.add(w.balls.first.pos);
      }
      return path;
    }

    final light = run(1.0);
    final heavy = run(5.4);
    expect(light.length, heavy.length);
    for (var i = 0; i < light.length; i++) {
      expect((light[i] - heavy[i]).length, lessThan(1e-9));
    }
  });

  // ---- スリーセブンスロット ----

  test('スロットの判定：7揃いは大当たり、他の3つ揃いは当たり', () {
    // 柄インデックス: 1→0, ... 7→6, ... 9→8, コイン→9
    expect(SlotMachine.evaluate([6, 6, 6]).isJackpot, isTrue); // 7-7-7
    expect(SlotMachine.evaluate([6, 6, 6]).matched, isTrue);
    expect(SlotMachine.evaluate([2, 2, 2]).matched, isTrue); // 3-3-3
    expect(SlotMachine.evaluate([2, 2, 2]).isJackpot, isFalse);
    expect(SlotMachine.evaluate([9, 9, 9]).matched, isTrue); // コイン揃い
    expect(SlotMachine.evaluate([9, 9, 9]).isJackpot, isFalse);
    expect(SlotMachine.evaluate([6, 6, 5]).matched, isFalse); // 7-7-6
    expect(SlotMachine.digitLabel(6), '7');
    expect(SlotMachine.digitLabel(SlotMachine.coinIndex), isNull);
  });

  test('スロットは3秒以内に3リールが順番に停止し、結果を1回だけ返す', () {
    final sl = SlotMachine(center: const Vec2(50, 49), seed: 1);
    expect(sl.isIdle, isTrue);
    sl.startSpin();
    expect(sl.isSpinning, isTrue);

    var t = 0.0;
    SlotResult? result;
    while (t < 5.0) {
      sl.step(1 / 60);
      t += 1 / 60;
      final r = sl.takePendingResult();
      if (r != null) {
        result = r;
        break;
      }
    }
    expect(result, isNotNull);
    expect(t, lessThanOrEqualTo(SlotMachine.maxSpinSeconds));
    expect(sl.reelSpinning.every((b) => !b), isTrue);
    // 結果は一度きり
    expect(sl.takePendingResult(), isNull);
  });

  test('回転中／演出中は新しい玉を受け付けない', () {
    final sl = SlotMachine(center: const Vec2(50, 49), seed: 3);
    sl.startSpin();
    // 回転中に startSpin しても状態は変わらない
    final targetsBefore = sl.visibleSymbols;
    sl.startSpin();
    expect(sl.isSpinning, isTrue);
    expect(sl.visibleSymbols, targetsBefore);
  });

  test('玉がスロットに入ると1回転開始し、揃えば賞球が加算される', () {
    final c = GameController()
      ..setInitialBallCount(1000)
      ..resetGame();

    // センサー位置へ直接玉を置いて入賞させる（狙って当てるのは不安定なため）。
    final slot = c.world.slot!;
    c.world.balls.add(Ball(
      pos: slot.center,
      vel: const Vec2(0, 5),
      inLane: false,
    ));
    c.tick(1 / 60);
    expect(c.stats.slotPlays, 1, reason: '玉入賞で1回転が始まる');
    expect(c.world.ballCount, 0, reason: '入賞した玉は消費される');
    expect(slot.isSpinning, isTrue);

    // 停止まで進める
    for (var k = 0; k < 60 * 4; k++) {
      c.tick(1 / 60);
    }
    // 何らかの結果が出て statesが整合している
    final total = c.stats.slotWins + c.stats.slotJackpots;
    expect(total, inInclusiveRange(0, 1));
    if (c.stats.slotJackpots == 1) {
      expect(c.remainingBalls, greaterThanOrEqualTo(1000 + 100));
    } else if (c.stats.slotWins == 1) {
      expect(c.remainingBalls, greaterThanOrEqualTo(1000 + 20));
    }
  });

  test('スロット統計は resetGame / resetStatsOnly で初期化される', () {
    final c = GameController()..resetGame();
    c.stats.slotPlays = 5;
    c.stats.slotWins = 2;
    c.stats.slotJackpots = 1;
    c.resetStatsOnly();
    expect(c.stats.slotPlays, 0);
    expect(c.stats.slotWins, 0);
    expect(c.stats.slotJackpots, 0);
  });
}
