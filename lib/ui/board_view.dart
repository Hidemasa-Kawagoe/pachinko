import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/game_controller.dart';
import 'board_painter.dart';

/// 盤面表示。内部に Ticker を持ち、毎フレーム [GameController.tick] を呼ぶ。
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.controller});

  final GameController controller;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    widget.controller.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.controller.manualLaunch(),
      child: Container(
        color: const Color(0xFF0C1B27),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return CustomPaint(
              painter: BoardPainter(world: widget.controller.world),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}
