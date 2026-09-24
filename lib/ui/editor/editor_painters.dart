import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../editor/block.dart';
import '../../editor/board_layout.dart';
import '../../models/board_pattern.dart' show kBoardWidth;

/// 要素マーカーの色。
Color elementColor(ElementKind k) {
  switch (k) {
    case ElementKind.nail:
      return const Color(0xFFE8E8EC);
    case ElementKind.winningHole:
      return const Color(0xFFE0A020);
    case ElementKind.slot:
      return const Color(0xFF8FD3FF);
    case ElementKind.tulip:
      return const Color(0xFFE74C3C);
  }
}

/// 要素1個を canvas に描く。[c] は画面上の中心、[u] は1ユニットあたりのピクセル。
void paintElementMarker(
  Canvas canvas,
  Offset c,
  double u,
  ElementKind kind, {
  bool selected = false,
  int payout = 0,
}) {
  switch (kind) {
    case ElementKind.nail:
      final nr = math.max(2.0, 0.9 * u);
      canvas.drawCircle(c, nr, Paint()..color = elementColor(kind));
      canvas.drawCircle(
        c,
        nr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withOpacity(0.35),
      );
      break;
    case ElementKind.winningHole:
      canvas.drawCircle(c, 2.2 * u,
          Paint()..color = const Color(0xFF0A1622));
      canvas.drawCircle(
        c,
        2.2 * u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, 0.6 * u)
          ..color = elementColor(kind),
      );
      if (u > 3) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$payout',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 2.0 * u,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
      break;
    case ElementKind.slot:
      final r = Rect.fromCenter(center: c, width: 8 * u, height: 6 * u);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(1.5 * u)),
        Paint()..color = const Color(0xFF23303D),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(1.5 * u)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = elementColor(kind),
      );
      break;
    case ElementKind.tulip:
      canvas.drawCircle(c, 2.0 * u,
          Paint()..color = const Color(0xFF0A1622));
      canvas.drawLine(c + Offset(-3 * u, 0), c + Offset(-1 * u, -4 * u),
          Paint()
            ..color = elementColor(kind)
            ..strokeWidth = math.max(2.0, 0.7 * u)
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(c + Offset(3 * u, 0), c + Offset(1 * u, -4 * u),
          Paint()
            ..color = elementColor(kind)
            ..strokeWidth = math.max(2.0, 0.7 * u)
            ..strokeCap = StrokeCap.round);
      break;
  }
  if (selected) {
    canvas.drawCircle(
      c,
      3.2 * u,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4CC2FF),
    );
  }
}

/// ブロック編集キャンバス（1ブロックだけを拡大表示）。
class BlockPainter extends CustomPainter {
  BlockPainter({required this.block, this.selectedIndex});

  final Block block;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / block.width; // px / unit
    final bg = Paint()..color = const Color(0xFF12324A);
    canvas.drawRect(Offset.zero & size, bg);

    // セルのグリッド
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;
    for (var c = 0; c <= block.cols; c++) {
      final x = c * kCellW * u;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var r = 0; r <= block.rows; r++) {
      final y = r * kCellH * u;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < block.elements.length; i++) {
      final e = block.elements[i];
      paintElementMarker(
        canvas,
        Offset(e.pos.x * u, e.pos.y * u),
        u,
        e.kind,
        selected: i == selectedIndex,
        payout: e.payout,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlockPainter oldDelegate) => true;
}

/// 配置編集キャンバス（台全体＋グリッド＋配置済みブロック）。
class LayoutPainter extends CustomPainter {
  LayoutPainter({required this.layout, this.selectedPlacementIndex});

  final BoardLayout layout;
  final int? selectedPlacementIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / kBoardWidth;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF16394F));

    // 8x8 グリッド
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    for (var c = 0; c <= kGridCols; c++) {
      final x = c * kCellW * u;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var r = 0; r <= kGridRows; r++) {
      final y = r * kCellH * u;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var pi = 0; pi < layout.placements.length; pi++) {
      final p = layout.placements[pi];
      final b = layout.blockById(p.blockId);
      if (b == null) continue;
      final o = p.origin;
      final selected = pi == selectedPlacementIndex;

      final rect = Rect.fromLTWH(
        o.x * u,
        o.y * u,
        b.width * u,
        b.height * u,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = (selected
              ? const Color(0x334CC2FF)
              : Colors.white.withOpacity(0.05)),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1.2
          ..color = selected
              ? const Color(0xFF4CC2FF)
              : Colors.white.withOpacity(0.35),
      );

      for (final e in b.elements) {
        final abs = o + e.pos;
        paintElementMarker(
          canvas,
          Offset(abs.x * u, abs.y * u),
          u,
          e.kind,
          payout: e.payout,
        );
      }

      // ブロック名
      final tp = TextPainter(
        text: TextSpan(
          text: b.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: math.max(9.0, 1.2 * u),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      tp.paint(canvas, rect.topLeft + const Offset(3, 2));
    }
  }

  @override
  bool shouldRepaint(covariant LayoutPainter oldDelegate) => true;
}
