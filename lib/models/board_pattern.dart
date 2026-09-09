import 'dart:math' as math;
import '../engine/vec2.dart';
import 'obstacles.dart';
import 'rotor.dart';
import 'slot_machine.dart';
import 'tulip.dart';

/// 盤面の論理サイズ（単位はゲーム内ユニット。描画時に画面へスケールする）。
const double kBoardWidth = 100.0;
const double kBoardHeight = 140.0;

/// 調整可能なパラメータ（分析タブから変更）。
///
/// Phase1 では「チューリップ手前の命釘（ヘソ釘）」の間隔と高さのみ調整できる。
class BoardConfig {
  /// 左右の命釘の間隔（ユニット）。狭いほどチューリップに入りにくい。
  double lifeNailGap;

  /// 命釘のチューリップ台座からの高さ（ユニット）。
  double lifeNailHeight;

  BoardConfig({
    this.lifeNailGap = 8.0,
    this.lifeNailHeight = 11.0,
  });

  BoardConfig copy() =>
      BoardConfig(lifeNailGap: lifeNailGap, lifeNailHeight: lifeNailHeight);

  static const double gapMin = 4.0;
  static const double gapMax = 14.0;
  static const double heightMin = 6.0;
  static const double heightMax = 18.0;

  static BoardConfig defaults() => BoardConfig();
}

/// 盤面パターン。あらかじめ用意した釘・入賞穴・役物の配置を生成する。
///
/// Phase1 では [phase1Standard] の1種類のみ。将来 Phase では複数登録し
/// [byId] で切り替えられるようにする。
abstract class BoardPattern {
  String get id;
  String get name;

  /// 発射レーンの玉の初期位置。
  Vec2 get launchPos;

  /// 発射方向（正規化済み）。
  Vec2 get launchDir;

  List<Segment> buildWalls();
  List<Nail> buildNails(BoardConfig config);
  Tulip buildTulip(BoardConfig config);
  List<WinningHole> buildWinningHoles();

  /// 回転体（無い台なら空リスト）。
  List<Rotor> buildRotors();

  /// 中央のスロット（無い台なら null）。
  SlotMachine? buildSlot();

  static final Map<String, BoardPattern> _registry = {
    Phase1StandardPattern().id: Phase1StandardPattern(),
  };

  static BoardPattern get phase1Standard => _registry['phase1_standard']!;

  static List<BoardPattern> get all => _registry.values.toList();

  static BoardPattern byId(String id) => _registry[id] ?? phase1Standard;
}

/// Phase1 標準パターン：中央下部に1基のチューリップ＋手前の命釘。
class Phase1StandardPattern implements BoardPattern {
  @override
  String get id => 'phase1_standard';

  @override
  String get name => 'Phase1 標準台（チューリップ1基）';

  /// チューリップ台座の基準位置。
  static const Vec2 tulipBase = Vec2(50, 104);

  /// 台中央のスロット。センサー中心と受け皿（表示パネル）の位置。
  static const Vec2 slotCenter = Vec2(50, 49);
  static const double slotSensorRadius = 2.6;

  /// スロットを挟んで左右に置く回転体（従来の半分サイズ）。
  static const Vec2 rotorLeftCenter = Vec2(32, 60);
  static const Vec2 rotorRightCenter = Vec2(68, 60);
  static const double rotorTipRadius = 2.8; // 従来 5.6 の半分
  static const double rotorHubRadius = 1.2; // 従来 2.4 の半分

  @override
  Vec2 get launchPos => const Vec2(95.0, 133);

  @override
  Vec2 get launchDir => const Vec2(0, -1);

  @override
  List<Segment> buildWalls() {
    final w = <Segment>[];

    // 左の外周壁
    w.add(const Segment(Vec2(8, 22), Vec2(8, 118), restitution: 0.3));

    // 発射レーン：外側の壁（右端）と内側の壁。玉はこの間（x=90〜97）を上昇する。
    w.add(const Segment(Vec2(97, 18), Vec2(97, 138), restitution: 0.2));
    w.add(const Segment(Vec2(90, 22), Vec2(90, 138), restitution: 0.2));

    // レーン上部の「返し」ランプ（急斜面）。上がってきた玉を左＝盤面へ蹴り出す。
    w.add(const Segment(Vec2(97, 16), Vec2(86, 6), restitution: 0.2));

    // 天井（低いカーブ）。強く撃った玉が飛び出さないよう左へ受け流す。
    final ceiling = <Vec2>[
      const Vec2(86, 6),
      const Vec2(74, 2.5),
      const Vec2(58, 1.5),
      const Vec2(42, 2),
      const Vec2(28, 4.5),
      const Vec2(17, 10),
      const Vec2(10, 18),
      const Vec2(8, 24),
    ];
    for (var i = 0; i < ceiling.length - 1; i++) {
      w.add(Segment(ceiling[i], ceiling[i + 1], restitution: 0.15));
    }

    // 下部の誘導（アウト口へ集める漏斗）。中央 x=44〜56 がアウト。
    // ※発射レーン（x>=90）は塞がないよう、右側は x=88 で止める。
    w.add(const Segment(Vec2(8, 116), Vec2(44, 136), restitution: 0.2));
    w.add(const Segment(Vec2(88, 112), Vec2(56, 136), restitution: 0.2));

    // 中央スロットの「屋根」（山なりのテント）。中央に隙間を残し、
    // 外れた玉は左右へ滑り落ちる（スロット本体に玉が詰まらないように）。
    w.add(const Segment(Vec2(38, 60), Vec2(47.4, 51), restitution: 0.15));
    w.add(const Segment(Vec2(52.6, 51), Vec2(62, 60), restitution: 0.15));

    return w;
  }

  @override
  List<Nail> buildNails(BoardConfig config) {
    final nails = <Nail>[];
    final holes = buildWinningHoles();

    bool nearHole(double x, double y) {
      for (final h in holes) {
        // 入賞穴まわりは弧状の釘を置くため、散らし釘は広めに空ける。
        if ((Vec2(x, y) - h.pos).length < h.radius + 7.5) return true;
      }
      return false;
    }

    // 中央ギミック（スロット・左右の回転体）まわりのクリアランス。
    bool nearSlot(double x, double y) =>
        (Vec2(x, y) - slotCenter).length < 9.5;
    bool nearRotor(double x, double y) =>
        (Vec2(x, y) - rotorLeftCenter).length < rotorTipRadius + 4.0 ||
        (Vec2(x, y) - rotorRightCenter).length < rotorTipRadius + 4.0;
    // スロット屋根の端と回転体の間に釘があると玉が挟まって詰まるため、
    // 屋根の両端の直下も釘を空ける。
    bool nearTentEnd(double x, double y) =>
        (Vec2(x, y) - const Vec2(38, 60)).length < 4.6 ||
        (Vec2(x, y) - const Vec2(62, 60)).length < 4.6;

    // --- 散らし釘（盤面全体のランダム風だが固定配置）---
    // 玉を十分に拡散させ、強さに対する入賞率がなめらかに変化するようにする。
    const rows = [30.0, 38.0, 46.0, 54.0, 62.0, 70.0, 78.0, 86.0];
    for (var r = 0; r < rows.length; r++) {
      final y = rows[r];
      final offset = (r.isEven) ? 0.0 : 4.7;
      for (var x = 15.0 + offset; x <= 87.0; x += 9.4) {
        // 下段では中央にチューリップへの導線を空ける
        if (y >= 62 && (x - 50).abs() < 10.5) continue;
        if (nearHole(x, y)) continue;
        if (nearSlot(x, y)) continue;
        if (nearRotor(x, y)) continue;
        if (nearTentEnd(x, y)) continue;
        nails.add(Nail(Vec2(x, y)));
      }
    }

    // --- スロットの入口へ寄せる軽い逆八の字（2本）---
    nails.add(Nail(const Vec2(45.5, 45.0)));
    nails.add(Nail(const Vec2(54.5, 45.0)));

    // --- 入賞穴の上の「短い弧」（隙間の小さい、左右3本ずつ＝計6本）---
    // 逆八の字（谷型）に配置して入賞穴へ玉を導く（入りやすくする）。
    // 中央は開けて左右2本の短い凹弧にするので、腕の間に玉が挟まって
    // 留まる配置にならない。弧の喉元へ来た玉はセンサーが取り込む
    // （下の catchRadius を玉半径ぶん広げてあるため、留まる前に入賞になる）。
    for (final h in holes) {
      final pivot = h.pos + const Vec2(0, -6.6);
      // 右腕（40°〜80°）と左腕（100°〜140°）で計6本の短い凹弧。
      // 真下(90°)付近は玉が通り抜けられるよう開ける。
      nails.addAll(_arcNails(pivot, 6.6, 40, 80, 3));
      nails.addAll(_arcNails(pivot, 6.6, 100, 140, 3));
    }

    // --- チューリップ手前の命釘（調整対象）---
    final baseY = tulipBase.y;
    final gap = config.lifeNailGap.clamp(BoardConfig.gapMin, BoardConfig.gapMax);
    final hgt = config.lifeNailHeight
        .clamp(BoardConfig.heightMin, BoardConfig.heightMax);

    // 左右のヘソ釘（命釘）
    nails.add(Nail(Vec2(50 - gap / 2, baseY - hgt),
        radius: 0.75, adjustable: true));
    nails.add(Nail(Vec2(50 + gap / 2, baseY - hgt),
        radius: 0.75, adjustable: true));

    // 上の振り分け釘（天釘）
    nails.add(Nail(Vec2(50, baseY - hgt - 6.5), radius: 0.75, adjustable: true));

    // 肩の釘（ヨロイ）：外側へこぼす
    nails.add(Nail(Vec2(50 - gap / 2 - 6.5, baseY - hgt + 2.5),
        radius: 0.75, adjustable: true));
    nails.add(Nail(Vec2(50 + gap / 2 + 6.5, baseY - hgt + 2.5),
        radius: 0.75, adjustable: true));

    // --- チューリップ横の道釘（外れ玉をアウト／入賞穴側へ誘導）---
    nails.add(Nail(Vec2(38, baseY - 1)));
    nails.add(Nail(Vec2(62, baseY - 1)));
    nails.add(Nail(Vec2(32, baseY + 6)));
    nails.add(Nail(Vec2(68, baseY + 6)));

    return nails;
  }

  @override
  Tulip buildTulip(BoardConfig config) {
    return Tulip(base: tulipBase, isOpen: false);
  }

  @override
  List<WinningHole> buildWinningHoles() {
    return [
      WinningHole(
          pos: const Vec2(23, 95), radius: 2.2, payout: 7, label: '入賞左'),
      WinningHole(
          pos: const Vec2(77, 95), radius: 2.2, payout: 7, label: '入賞右'),
    ];
  }

  @override
  List<Rotor> buildRotors() => [
        Rotor(
          center: rotorLeftCenter,
          hubRadius: rotorHubRadius,
          tipRadius: rotorTipRadius,
          blades: 6,
          massGrams: 6.0, // サイズを半分にしたので質量も軽く
        ),
        Rotor(
          center: rotorRightCenter,
          hubRadius: rotorHubRadius,
          tipRadius: rotorTipRadius,
          blades: 6,
          massGrams: 6.0,
        ),
      ];

  @override
  SlotMachine? buildSlot() =>
      SlotMachine(center: slotCenter, sensorRadius: slotSensorRadius);
}

/// 弧状に釘を並べる。
///
/// [pivot] を中心に半径 [radius]、[startDeg]〜[endDeg] の範囲へ [count] 本。
/// 凸（山なり）に使えば玉は必ず斜面に乗り、一点に留まらない
/// （＝玉が落ちなくなる配置を避ける）。隙間は釘間隔で小さく保つ。
List<Nail> _arcNails(
  Vec2 pivot,
  double radius,
  double startDeg,
  double endDeg,
  int count,
) {
  final list = <Nail>[];
  for (var i = 0; i < count; i++) {
    final t = count <= 1 ? 0.5 : i / (count - 1);
    final rad = (startDeg + (endDeg - startDeg) * t) * math.pi / 180.0;
    list.add(Nail(pivot + Vec2(math.cos(rad), math.sin(rad)) * radius));
  }
  return list;
}

/// 度数 → ラジアン（未使用時の警告回避も兼ねたユーティリティ）。
double degToRad(double d) => d * math.pi / 180.0;
