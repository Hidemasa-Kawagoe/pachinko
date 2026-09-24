import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../editor/block.dart';
import '../../editor/board_layout.dart';
import '../../editor/editor_controller.dart';
import '../../engine/vec2.dart';
import '../../models/board_pattern.dart' show kBoardWidth, kBoardHeight;
import 'editor_painters.dart';

/// 編集モード画面。上部に「配置編集／ブロック編集」の切替、下部に反映ボタン。
class EditorPage extends StatelessWidget {
  const EditorPage({
    super.key,
    required this.editor,
    required this.onApply,
    required this.defaultBuilder,
  });

  final EditorController editor;

  /// レイアウトを台へ反映する（null は既定台へ）。
  final void Function(BoardLayout? layout) onApply;

  /// 「既定レイアウト」を作る関数（buildPhase1Layout）。
  final BoardLayout Function() defaultBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: editor,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<EditorMode>(
                      segments: const [
                        ButtonSegment(
                            value: EditorMode.placement,
                            label: Text('配置編集'),
                            icon: Icon(Icons.grid_on)),
                        ButtonSegment(
                            value: EditorMode.blockEdit,
                            label: Text('ブロック編集'),
                            icon: Icon(Icons.widgets_outlined)),
                      ],
                      selected: {editor.mode},
                      onSelectionChanged: (s) => editor.setMode(s.first),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: editor.mode == EditorMode.placement
                  ? _PlacementEditView(ec: editor)
                  : _BlockEditView(ec: editor),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        editor.replaceLayout(defaultBuilder()),
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('既定レイアウト読込'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => onApply(editor.layout),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('プレイに反映'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// アスペクト比を保ってフィットさせ、タップ／ドラッグ位置を「ユニット座標」で返す。
class _FittedCanvas extends StatelessWidget {
  const _FittedCanvas({
    required this.unitsWide,
    required this.unitsTall,
    required this.painter,
    this.onTapDown,
    this.onPanUpdate,
  });

  final double unitsWide;
  final double unitsTall;
  final CustomPainter painter;
  final void Function(Offset unitPos)? onTapDown;
  final void Function(Offset unitPos)? onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final aspect = unitsWide / unitsTall;
        var w = cons.maxWidth.isFinite ? cons.maxWidth : 320.0;
        var h = cons.maxHeight.isFinite ? cons.maxHeight : w / aspect;
        if (w / h > aspect) {
          w = h * aspect;
        } else {
          h = w / aspect;
        }
        final scale = w / unitsWide;
        Offset toUnit(Offset p) => Offset(p.dx / scale, p.dy / scale);
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onTapDown == null
                  ? null
                  : (d) => onTapDown!(toUnit(d.localPosition)),
              onPanUpdate: onPanUpdate == null
                  ? null
                  : (d) => onPanUpdate!(toUnit(d.localPosition)),
              child: CustomPaint(painter: painter, size: Size(w, h)),
            ),
          ),
        );
      },
    );
  }
}

// ---------------- 配置編集 ----------------

class _PlacementEditView extends StatelessWidget {
  const _PlacementEditView({required this.ec});
  final EditorController ec;

  int? _placementAt(Offset u) {
    for (var i = ec.layout.placements.length - 1; i >= 0; i--) {
      final p = ec.layout.placements[i];
      final b = ec.layout.blockById(p.blockId);
      if (b == null) continue;
      final o = p.origin;
      if (u.dx >= o.x &&
          u.dx <= o.x + b.width &&
          u.dy >= o.y &&
          u.dy <= o.y + b.height) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sel = ec.selectedPlacement;
    final selBlock = sel == null ? null : ec.layout.blockById(sel.blockId);
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final b in ec.layout.blocks)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(b.name),
                    selected: ec.selectedBlockId == b.id,
                    onSelected: (_) => ec.selectBlock(b.id),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ブロックを選んでグリッドをタップ＝配置／配置をタップ＝選択・移動',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _FittedCanvas(
              unitsWide: kBoardWidth,
              unitsTall: kBoardHeight,
              painter: LayoutPainter(
                layout: ec.layout,
                selectedPlacementIndex: ec.selectedPlacementIndex,
              ),
              onTapDown: (u) {
                final hit = _placementAt(u);
                if (hit != null && hit != ec.selectedPlacementIndex) {
                  ec.selectPlacement(hit);
                  return;
                }
                final col =
                    (u.dx / kCellW).floor().clamp(0, kGridCols - 1);
                final row =
                    (u.dy / kCellH).floor().clamp(0, kGridRows - 1);
                if (ec.selectedPlacement != null) {
                  ec.moveSelectedPlacement(col, row);
                } else if (ec.selectedBlockId != null) {
                  ec.placeSelectedBlockAt(col, row);
                }
              },
            ),
          ),
        ),
        if (sel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '選択中: ${selBlock?.name ?? '?'}  (${sel.col}, ${sel.row})',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ec.selectPlacement(null),
                  icon: const Icon(Icons.close),
                  label: const Text('選択解除'),
                ),
                TextButton.icon(
                  onPressed: ec.deleteSelectedPlacement,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('削除'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------- ブロック編集 ----------------

class _BlockEditView extends StatelessWidget {
  const _BlockEditView({required this.ec});
  final EditorController ec;

  int? _elementAt(Block b, Offset u) {
    var best = -1;
    var bestD = 4.0;
    for (var i = 0; i < b.elements.length; i++) {
      final d = (Vec2(u.dx, u.dy) - b.elements[i].pos).length;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  @override
  Widget build(BuildContext context) {
    final b = ec.selectedBlock;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ec.selectedBlockId,
                  hint: const Text('ブロックなし'),
                  items: [
                    for (final blk in ec.layout.blocks)
                      DropdownMenuItem(value: blk.id, child: Text(blk.name)),
                  ],
                  onChanged: (id) => id == null ? null : ec.selectBlock(id),
                ),
              ),
              IconButton(
                onPressed: ec.addBlock,
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'ブロック追加',
              ),
              IconButton(
                onPressed: b == null ? null : ec.deleteSelectedBlock,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'ブロック削除',
              ),
            ],
          ),
          if (b == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('「＋」でブロックを追加してください'),
            )
          else ...[
            TextFormField(
              key: ValueKey('name_${b.id}'),
              initialValue: b.name,
              decoration: const InputDecoration(
                labelText: 'ブロック名',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: ec.renameSelectedBlock,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Stepper(
                  label: '列',
                  value: b.cols,
                  min: 1,
                  max: kGridCols,
                  onChanged: (v) => ec.setSelectedBlockSize(v, b.rows),
                ),
                const SizedBox(width: 16),
                _Stepper(
                  label: '行',
                  value: b.rows,
                  min: 1,
                  max: kGridRows,
                  onChanged: (v) => ec.setSelectedBlockSize(b.cols, v),
                ),
                const Spacer(),
                Text('最小 1/64（1セル）',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final k in ElementKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: ec.paletteKind == k,
                    onSelected: (_) => ec.setPaletteKind(k),
                  ),
              ],
            ),
            if (ec.paletteKind == ElementKind.winningHole ||
                ec.selectedElement?.kind == ElementKind.winningHole)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Text('入賞の玉加算数: '),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        key: ValueKey(
                            'payout_${b.id}_${ec.selectedElementIndex}'),
                        initialValue: '${ec.selectedElement?.kind == ElementKind.winningHole ? ec.selectedElement!.payout : ec.palettePayout}',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            isDense: true, border: OutlineInputBorder()),
                        onChanged: (t) {
                          final v = int.tryParse(t);
                          if (v != null) ec.setPalettePayout(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '空きをタップ＝${ec.paletteKind.label}を追加／要素をタップ＝選択／ドラッグ＝移動',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 320,
              child: _FittedCanvas(
                unitsWide: b.width,
                unitsTall: b.height,
                painter: BlockPainter(
                  block: b,
                  selectedIndex: ec.selectedElementIndex,
                ),
                onTapDown: (u) {
                  final hit = _elementAt(b, u);
                  if (hit != null) {
                    ec.selectElement(hit);
                  } else {
                    ec.addElementAt(Vec2(u.dx, u.dy));
                  }
                },
                onPanUpdate: (u) {
                  if (ec.selectedElement == null) return;
                  ec.moveSelectedElement(Vec2(
                    u.dx.clamp(0.0, b.width),
                    u.dy.clamp(0.0, b.height),
                  ));
                },
              ),
            ),
            if (ec.selectedElement != null)
              Row(
                children: [
                  Expanded(
                      child: Text('選択要素: ${ec.selectedElement!.kind.label}')),
                  TextButton.icon(
                    onPressed: () => ec.selectElement(null),
                    icon: const Icon(Icons.close),
                    label: const Text('選択解除'),
                  ),
                  TextButton.icon(
                    onPressed: ec.deleteSelectedElement,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('削除'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label '),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
