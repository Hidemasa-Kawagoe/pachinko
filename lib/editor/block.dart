import '../engine/vec2.dart';
import '../models/board_pattern.dart' show kBoardWidth, kBoardHeight;

/// 台を格子（グリッド）に分割する数。最小ブロック ＝ 台の 1/64 ＝ 1セル。
const int kGridCols = 8;
const int kGridRows = 8;

/// 1セルの大きさ（盤面ユニット）。
const double kCellW = kBoardWidth / kGridCols; // 12.5
const double kCellH = kBoardHeight / kGridRows; // 17.5

/// ブロック内に置ける要素の種類。
enum ElementKind { nail, winningHole, slot, tulip }

extension ElementKindLabel on ElementKind {
  String get label {
    switch (this) {
      case ElementKind.nail:
        return '釘';
      case ElementKind.winningHole:
        return '入賞';
      case ElementKind.slot:
        return 'スロット';
      case ElementKind.tulip:
        return 'チューリップ';
    }
  }
}

/// ブロック内の1要素。[pos] はブロック原点（左上）からの相対座標（盤面ユニット）。
class BlockElement {
  ElementKind kind;
  Vec2 pos;

  /// 入賞のときの賞球数（玉加算数）。
  int payout;

  BlockElement({required this.kind, required this.pos, this.payout = 10});

  BlockElement copy() =>
      BlockElement(kind: kind, pos: pos, payout: payout);

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'x': pos.x,
        'y': pos.y,
        if (kind == ElementKind.winningHole) 'payout': payout,
      };

  factory BlockElement.fromJson(Map<String, dynamic> j) => BlockElement(
        kind: ElementKind.values.byName(j['kind'] as String),
        pos: Vec2((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        payout: (j['payout'] as num?)?.toInt() ?? 10,
      );
}

/// 配置パターンの構成単位。釘・入賞・スロット・チューリップをまとめた「1ブロック」。
///
/// 大きさは [cols] × [rows] セル（各セル = 台の 1/64）。縦横は任意。
class Block {
  String id;
  String name;
  int cols;
  int rows;
  final List<BlockElement> elements;

  Block({
    required this.id,
    required this.name,
    this.cols = 2,
    this.rows = 2,
    List<BlockElement>? elements,
  }) : elements = elements ?? <BlockElement>[];

  double get width => cols * kCellW;
  double get height => rows * kCellH;

  Block copy() => Block(
        id: id,
        name: name,
        cols: cols,
        rows: rows,
        elements: elements.map((e) => e.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cols': cols,
        'rows': rows,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        id: j['id'] as String,
        name: j['name'] as String,
        cols: (j['cols'] as num).toInt(),
        rows: (j['rows'] as num).toInt(),
        elements: (j['elements'] as List)
            .map((e) => BlockElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 台上へのブロック配置。[col],[row] はブロック左上セルのグリッド位置。
class BlockPlacement {
  String blockId;
  int col;
  int row;

  BlockPlacement({required this.blockId, required this.col, required this.row});

  /// 盤面ユニットでのブロック原点。
  Vec2 get origin => Vec2(col * kCellW, row * kCellH);

  BlockPlacement copy() =>
      BlockPlacement(blockId: blockId, col: col, row: row);

  Map<String, dynamic> toJson() => {'blockId': blockId, 'col': col, 'row': row};

  factory BlockPlacement.fromJson(Map<String, dynamic> j) => BlockPlacement(
        blockId: j['blockId'] as String,
        col: (j['col'] as num).toInt(),
        row: (j['row'] as num).toInt(),
      );
}
