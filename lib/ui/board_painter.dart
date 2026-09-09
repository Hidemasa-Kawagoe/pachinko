import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../engine/physics_world.dart';
import '../engine/vec2.dart';
import '../models/board_pattern.dart';
import '../models/rotor.dart';
import '../models/slot_machine.dart';

/// 盤面（釘・チューリップ・入賞穴・玉）を描画する CustomPainter。
class BoardPainter extends CustomPainter {
  BoardPainter({required this.world}) : super(repaint: null);

  final PhysicsWorld world;

  late double _scale;
  late Offset _origin;

  Offset _p(Vec2 v) => _origin + Offset(v.x * _scale, v.y * _scale);

  @override
  void paint(Canvas canvas, Size size) {
    _scale = math.min(size.width / kBoardWidth, size.height / kBoardHeight);
    final drawnW = kBoardWidth * _scale;
    final drawnH = kBoardHeight * _scale;
    _origin = Offset((size.width - drawnW) / 2, (size.height - drawnH) / 2);

    _paintBackground(canvas);
    _paintWalls(canvas);
    _paintWinningHoles(canvas);
    _paintTulip(canvas);
    _paintRotors(canvas);
    _paintNails(canvas);
    _paintSlot(canvas);
    _paintBalls(canvas);
    _paintFrame(canvas);
  }

  void _paintRotors(Canvas canvas) {
    for (final rt in world.rotors) {
      _paintRotor(canvas, rt);
    }
  }

  void _paintRotor(Canvas canvas, Rotor rt) {
    final c = _p(rt.center);

    // 外周のガイド円（うっすら）
    canvas.drawCircle(
      c,
      rt.tipRadius * _scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.12),
    );

    // 羽根
    final bladePaint = Paint()
      ..color = const Color(0xFFCBB26A)
      ..strokeWidth = math.max(2.0, 2.0 * _scale)
      ..strokeCap = StrokeCap.round;
    final tipPaint = Paint()..color = const Color(0xFFF0DFA8);
    for (final (a, b) in rt.bladeSegments()) {
      canvas.drawLine(_p(a), _p(b), bladePaint);
      canvas.drawCircle(_p(b), 1.0 * _scale, tipPaint);
    }

    // ハブ
    canvas.drawCircle(
        c, rt.hubRadius * _scale, Paint()..color = const Color(0xFF6E6250));
    canvas.drawCircle(
      c,
      rt.hubRadius * _scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.black.withOpacity(0.4),
    );
    // 回転が分かるマーカー
    final mark = rt.bladeSegments().first.$2;
    canvas.drawCircle(
        _p(mark), 0.6 * _scale, Paint()..color = const Color(0xFFB23B3B));
  }

  void _paintSlot(Canvas canvas) {
    final sl = world.slot;
    if (sl == null) return;

    final blinkOn = sl.isBlinking && ((sl.blinkTimer * 8).floor().isEven);

    // 本体パネル（センサーの少し下）
    final panelW = 16.0 * _scale;
    final panelH = 13.0 * _scale;
    final panelCenter = _p(sl.center + const Vec2(0, 8.5));
    final panelRect = Rect.fromCenter(
        center: panelCenter, width: panelW, height: panelH);
    final panelRRect =
        RRect.fromRectAndRadius(panelRect, Radius.circular(2.0 * _scale));
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = blinkOn ? const Color(0xFFFFE14D) : const Color(0xFF23303D),
    );
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, 1.6 * _scale)
        ..color = blinkOn ? const Color(0xFFFF5252) : const Color(0xFFC9A24B),
    );

    // 3つのリール窓
    final reelW = panelW / 3.6;
    final reelH = panelH * 0.66;
    final gap = (panelW - reelW * 3) / 4;
    for (var i = 0; i < 3; i++) {
      final left = panelRect.left + gap + i * (reelW + gap);
      final winRect =
          Rect.fromLTWH(left, panelCenter.dy - reelH / 2, reelW, reelH);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
          winRect, Radius.circular(1.5 * _scale)));
      canvas.drawRect(winRect, Paint()..color = const Color(0xFFF4F1E8));

      final pos = sl.reelPos[i];
      final base = pos.floorToDouble();
      final frac = pos - base;
      for (var k = -1; k <= 1; k++) {
        final idx = (base.toInt() + k) % SlotMachine.symbolCount;
        final sy = winRect.center.dy - (k - frac) * reelH;
        _paintSymbol(canvas, idx, Offset(winRect.center.dx, sy),
            reelH * 0.42, blinkOn);
      }
      canvas.restore();

      canvas.drawRRect(
        RRect.fromRectAndRadius(winRect, Radius.circular(1.5 * _scale)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.black.withOpacity(0.35),
      );
    }

    // 上部の投入口
    canvas.drawCircle(
      _p(sl.center),
      sl.sensorRadius * _scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, 1.4 * _scale)
        ..color = sl.isIdle
            ? const Color(0xFF8FE3B0)
            : Colors.white.withOpacity(0.25),
    );
  }

  void _paintSymbol(
      Canvas canvas, int idx, Offset center, double size, bool blinkOn) {
    final label = SlotMachine.digitLabel(idx);
    final isSeven = idx == SlotMachine.sevenIndex;
    final color = isSeven
        ? const Color(0xFFD32F2F)
        : (blinkOn ? const Color(0xFFB26A00) : const Color(0xFF2A2A2A));
    if (label == null) {
      // コイン
      canvas.drawCircle(
          center, size * 0.62, Paint()..color = const Color(0xFFE7B84B));
      canvas.drawCircle(
        center,
        size * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF9A7423),
      );
      canvas.drawCircle(
          center, size * 0.32, Paint()..color = const Color(0xFFF3D888));
      return;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintBackground(Canvas canvas) {
    final rect = Rect.fromLTWH(
        _origin.dx, _origin.dy, kBoardWidth * _scale, kBoardHeight * _scale);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(6 * _scale));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF204A6B), Color(0xFF12324A)],
        ).createShader(rect),
    );

    // うっすらとした同心円の意匠（1970年代の盤面風）
    final deco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.04);
    final center = _p(const Vec2(50, 70));
    for (var r = 8.0; r < 60; r += 8) {
      canvas.drawCircle(center, r * _scale, deco);
    }
  }

  void _paintFrame(Canvas canvas) {
    final rect = Rect.fromLTWH(
        _origin.dx, _origin.dy, kBoardWidth * _scale, kBoardHeight * _scale);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(6 * _scale));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFF6B4A2B),
    );
  }

  void _paintWalls(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFBFD8E8)
      ..strokeWidth = math.max(1.5, 1.4 * _scale)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in world.walls) {
      canvas.drawLine(_p(s.a), _p(s.b), paint);
    }
  }

  void _paintNails(Canvas canvas) {
    final normal = Paint()..color = const Color(0xFFE8E8EC);
    final normalRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withOpacity(0.35);
    final adj = Paint()..color = const Color(0xFFFFC24B);
    final adjRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8A5A00);

    for (final n in world.nails) {
      final c = _p(n.pos);
      final r = n.radius * _scale;
      if (n.adjustable) {
        canvas.drawCircle(c, r + 1.5, adjRim);
        canvas.drawCircle(c, r, adj);
      } else {
        canvas.drawCircle(c, r, normal);
        canvas.drawCircle(c, r, normalRim);
      }
    }
  }

  void _paintWinningHoles(Canvas canvas) {
    for (final h in world.holes) {
      final c = _p(h.pos);
      final r = h.radius * _scale;
      canvas.drawCircle(c, r + 2.0,
          Paint()..color = const Color(0xFFE0A020));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A1622));
      // ラベル
      final tp = TextPainter(
        text: TextSpan(
          text: '${h.payout}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 6 * _scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintTulip(Canvas canvas) {
    final t = world.tulip;
    final open = t.animT;

    // センサーの光（開いているほど強い）
    final glow = Paint()
      ..color = Color.lerp(
          const Color(0x00FF5252), const Color(0x66FF5252), open)!;
    canvas.drawCircle(_p(t.sensorCenter), t.sensorRadius * _scale * 1.4, glow);

    // 口（受け皿）
    final cupPaint = Paint()..color = const Color(0xFF0A1622);
    canvas.drawCircle(_p(t.base + const Vec2(0, 0.5)), 2.4 * _scale, cupPaint);

    // 羽根
    final petalPaint = Paint()
      ..color = Color.lerp(
          const Color(0xFFB23B3B), const Color(0xFFE74C3C), open)!
      ..strokeWidth = math.max(2.0, 2.2 * _scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(t.leftRoot), _p(t.leftTip), petalPaint);
    canvas.drawLine(_p(t.rightRoot), _p(t.rightTip), petalPaint);

    // 羽根の先端
    final tipPaint = Paint()..color = const Color(0xFFF5D76E);
    canvas.drawCircle(_p(t.leftTip), 1.4 * _scale, tipPaint);
    canvas.drawCircle(_p(t.rightTip), 1.4 * _scale, tipPaint);

    // 台座
    canvas.drawRect(
      Rect.fromCenter(
        center: _p(t.base + const Vec2(0, 2.5)),
        width: 8 * _scale,
        height: 3 * _scale,
      ),
      Paint()..color = const Color(0xFF3A2A1A),
    );
  }

  void _paintBalls(Canvas canvas) {
    for (final b in world.balls) {
      final c = _p(b.pos);
      final r = b.radius * _scale;
      canvas.drawCircle(c, r,
          Paint()..color = const Color(0xFFB8BCC4));
      canvas.drawCircle(
        c - Offset(r * 0.3, r * 0.3),
        r * 0.4,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.black.withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
