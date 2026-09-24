import 'package:flutter/foundation.dart';

import '../engine/vec2.dart';
import 'block.dart';
import 'board_layout.dart';

/// 編集モードの2つのサブモード。
enum EditorMode { blockEdit, placement }

/// 編集モードの状態と操作をまとめたコントローラ。
class EditorController extends ChangeNotifier {
  EditorController(this.layout) {
    selectedBlockId =
        layout.blocks.isNotEmpty ? layout.blocks.first.id : null;
  }

  BoardLayout layout;

  EditorMode mode = EditorMode.placement;

  /// ブロック編集で編集中／配置編集で配置しようとしているブロック。
  String? selectedBlockId;

  /// ブロック編集で選択中の要素インデックス。
  int? selectedElementIndex;

  /// 配置編集で選択中の配置インデックス。
  int? selectedPlacementIndex;

  /// ブロック編集で追加する要素の種類。
  ElementKind paletteKind = ElementKind.nail;

  /// 入賞要素の賞球数（パレット設定）。
  int palettePayout = 10;

  int _idSeq = 0;

  Block? get selectedBlock {
    final id = selectedBlockId;
    if (id == null) return null;
    return layout.blockById(id);
  }

  BlockElement? get selectedElement {
    final b = selectedBlock;
    final i = selectedElementIndex;
    if (b == null || i == null || i < 0 || i >= b.elements.length) return null;
    return b.elements[i];
  }

  BlockPlacement? get selectedPlacement {
    final i = selectedPlacementIndex;
    if (i == null || i < 0 || i >= layout.placements.length) return null;
    return layout.placements[i];
  }

  void setMode(EditorMode m) {
    mode = m;
    notifyListeners();
  }

  // --- ブロックライブラリ ---

  String _newId() {
    _idSeq++;
    var id = 'blk$_idSeq';
    while (layout.blockById(id) != null) {
      _idSeq++;
      id = 'blk$_idSeq';
    }
    return id;
  }

  void addBlock() {
    final b = Block(id: _newId(), name: '新規ブロック', cols: 2, rows: 2);
    layout.blocks.add(b);
    selectedBlockId = b.id;
    selectedElementIndex = null;
    notifyListeners();
  }

  void selectBlock(String id) {
    selectedBlockId = id;
    selectedElementIndex = null;
    notifyListeners();
  }

  void deleteSelectedBlock() {
    final id = selectedBlockId;
    if (id == null) return;
    layout.blocks.removeWhere((b) => b.id == id);
    layout.placements.removeWhere((p) => p.blockId == id);
    selectedBlockId =
        layout.blocks.isNotEmpty ? layout.blocks.first.id : null;
    selectedElementIndex = null;
    selectedPlacementIndex = null;
    notifyListeners();
  }

  void renameSelectedBlock(String name) {
    final b = selectedBlock;
    if (b == null) return;
    b.name = name;
    notifyListeners();
  }

  void setSelectedBlockSize(int cols, int rows) {
    final b = selectedBlock;
    if (b == null) return;
    b.cols = cols.clamp(1, kGridCols);
    b.rows = rows.clamp(1, kGridRows);
    notifyListeners();
  }

  // --- ブロック内の要素 ---

  void setPaletteKind(ElementKind k) {
    paletteKind = k;
    notifyListeners();
  }

  void setPalettePayout(int p) {
    palettePayout = p.clamp(0, 100000);
    final e = selectedElement;
    if (e != null && e.kind == ElementKind.winningHole) {
      e.payout = palettePayout;
    }
    notifyListeners();
  }

  void addElementAt(Vec2 relPos) {
    final b = selectedBlock;
    if (b == null) return;
    b.elements.add(BlockElement(
      kind: paletteKind,
      pos: relPos,
      payout: palettePayout,
    ));
    selectedElementIndex = b.elements.length - 1;
    notifyListeners();
  }

  void selectElement(int? i) {
    selectedElementIndex = i;
    notifyListeners();
  }

  void moveSelectedElement(Vec2 relPos) {
    final e = selectedElement;
    if (e == null) return;
    e.pos = relPos;
    notifyListeners();
  }

  void deleteSelectedElement() {
    final b = selectedBlock;
    final i = selectedElementIndex;
    if (b == null || i == null || i < 0 || i >= b.elements.length) return;
    b.elements.removeAt(i);
    selectedElementIndex = null;
    notifyListeners();
  }

  // --- 配置 ---

  void placeSelectedBlockAt(int col, int row) {
    final id = selectedBlockId;
    if (id == null) return;
    layout.placements.add(BlockPlacement(
      blockId: id,
      col: col.clamp(0, kGridCols - 1),
      row: row.clamp(0, kGridRows - 1),
    ));
    selectedPlacementIndex = layout.placements.length - 1;
    notifyListeners();
  }

  void selectPlacement(int? i) {
    selectedPlacementIndex = i;
    notifyListeners();
  }

  void moveSelectedPlacement(int col, int row) {
    final p = selectedPlacement;
    if (p == null) return;
    p.col = col.clamp(0, kGridCols - 1);
    p.row = row.clamp(0, kGridRows - 1);
    notifyListeners();
  }

  void deleteSelectedPlacement() {
    final i = selectedPlacementIndex;
    if (i == null || i < 0 || i >= layout.placements.length) return;
    layout.placements.removeAt(i);
    selectedPlacementIndex = null;
    notifyListeners();
  }

  /// レイアウト全体を差し替える（「既定に戻す」など）。
  void replaceLayout(BoardLayout next) {
    layout = next;
    selectedBlockId =
        layout.blocks.isNotEmpty ? layout.blocks.first.id : null;
    selectedElementIndex = null;
    selectedPlacementIndex = null;
    notifyListeners();
  }
}
