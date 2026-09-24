import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../editor/layout_presets.dart';
import '../engine/game_controller.dart';
import 'board_view.dart';
import 'editor/editor_page.dart';
import 'panels.dart';

enum AppMode { play, edit }

/// メイン画面。「遊技」（盤面＋発射／分析／設定）と「編集」を切り替える。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GameController _controller = GameController();
  EditorController? _editor;
  AppMode _mode = AppMode.play;

  @override
  void dispose() {
    _controller.dispose();
    _editor?.dispose();
    super.dispose();
  }

  void _enterEdit() {
    _editor ??= EditorController(
      (_controller.customLayout ?? buildPhase1Layout()).copy(),
    );
    setState(() => _mode = AppMode.edit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パチンコ シミュレータ  ―  Phase1'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: SegmentedButton<AppMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: AppMode.play, label: Text('遊技')),
                ButtonSegment(value: AppMode.edit, label: Text('編集')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                if (s.first == AppMode.edit) {
                  _enterEdit();
                } else {
                  setState(() => _mode = AppMode.play);
                }
              },
            ),
          ),
          if (_mode == AppMode.play)
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
      body: _mode == AppMode.play ? _buildPlay(context) : _buildEdit(context),
    );
  }

  Widget _buildEdit(BuildContext context) {
    return EditorPage(
      editor: _editor!,
      defaultBuilder: buildPhase1Layout,
      onApply: (layout) {
        _controller.applyLayout(layout);
        setState(() => _mode = AppMode.play);
      },
    );
  }

  Widget _buildPlay(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
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
    );
  }

  double _panelHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h * 0.42).clamp(240.0, 420.0);
  }
}
