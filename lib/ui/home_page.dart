import 'package:flutter/material.dart';

import '../engine/game_controller.dart';
import 'board_view.dart';
import 'panels.dart';

/// メイン画面。上部に盤面、下部に「発射／分析／設定」タブ。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GameController _controller = GameController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('パチンコ シミュレータ  ―  Phase1'),
          actions: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '玉 ${_controller.remainingBalls}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              flex: 3,
              child: BoardView(controller: _controller),
            ),
            Material(
              elevation: 8,
              child: SizedBox(
                height: _panelHeight(context),
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: '発射'),
                        Tab(text: '分析'),
                        Tab(text: '設定'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          LaunchPanel(controller: _controller),
                          AnalysisPanel(controller: _controller),
                          SettingsPanel(controller: _controller),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _panelHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h * 0.42).clamp(240.0, 420.0);
  }
}
