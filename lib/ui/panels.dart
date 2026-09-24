import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/game_controller.dart';
import '../models/board_pattern.dart';

/// 発射操作パネル（強さ・手動／自動発射・持ち玉・リセット）。
class LaunchPanel extends StatelessWidget {
  const LaunchPanel({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final empty = controller.remainingBalls <= 0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(label: '持ち玉', value: '${controller.remainingBalls}'),
                  _Stat(label: '盤上の玉', value: '${controller.world.ballCount}'),
                  _Stat(label: '発射数', value: '${controller.stats.launched}'),
                ],
              ),
              const SizedBox(height: 12),
              Text('発射の強さ： ${controller.strength.round()}',
                  style: Theme.of(context).textTheme.titleSmall),
              Slider(
                min: 0,
                max: 100,
                divisions: 100,
                value: controller.strength,
                label: controller.strength.round().toString(),
                onChanged: controller.setStrength,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: empty ? null : controller.manualLaunch,
                      icon: const Icon(Icons.circle),
                      label: const Text('手動発射（1発）'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: empty ? null : controller.toggleAuto,
                      icon: Icon(controller.autoLaunching
                          ? Icons.stop
                          : Icons.play_arrow),
                      label: Text(
                          controller.autoLaunching ? '自動停止' : '自動発射（0.5秒毎）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.resetGame,
                icon: const Icon(Icons.refresh),
                label: Text('リセット（持ち玉を ${controller.initialBallCount} に戻す）'),
              ),
              if (empty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('持ち玉がありません。リセットしてください。',
                      style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 分析パネル（統計表示＋チューリップ手前の釘調整）。
class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.stats;
        final cfg = controller.config;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('統計', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Stat(label: '発射数', value: '${s.launched}'),
                  _Stat(label: '盤面到達', value: '${s.validLaunched}'),
                  _Stat(label: 'チューリップ入賞', value: '${s.tulipIn}'),
                  _Stat(
                      label: 'チューリップ入賞率',
                      value: '${(s.tulipRate * 100).toStringAsFixed(1)}%'),
                  _Stat(label: '入賞穴', value: '${s.winning}'),
                  _Stat(label: 'アウト', value: '${s.out}'),
                  _Stat(label: 'ファウル', value: '${s.foul}'),
                  _Stat(label: '払出賞球（累計）', value: '${s.payoutTotal}'),
                ],
              ),
              const SizedBox(height: 16),
              Text('スロット', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Stat(label: 'スロット入賞', value: '${s.slotPlays}'),
                  _Stat(label: '当たり', value: '${s.slotWins}'),
                  _Stat(label: '大当たり', value: '${s.slotJackpots}'),
                  _Stat(
                      label: '当たり率',
                      value: '${(s.slotHitRate * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.resetStatsOnly,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('統計のみリセット'),
              ),
              const Divider(height: 32),
              Text('チューリップ手前の釘（命釘）の調整',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (controller.usingCustomLayout)
                Text(
                  'カスタム台（編集モードで作成）を使用中のため無効です。'
                  '釘の調整は編集モードで行ってください。',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange),
                )
              else ...[
                Text(
                  '間隔を広げるとチューリップに入りやすく、狭めると入りにくくなります。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _ConfigSlider(
                  label: '命釘の間隔',
                  value: cfg.lifeNailGap,
                  min: BoardConfig.gapMin,
                  max: BoardConfig.gapMax,
                  onChanged: (v) {
                    final c = cfg.copy()..lifeNailGap = v;
                    controller.updateConfig(c);
                  },
                ),
                _ConfigSlider(
                  label: '命釘の高さ（チューリップからの距離）',
                  value: cfg.lifeNailHeight,
                  min: BoardConfig.heightMin,
                  max: BoardConfig.heightMax,
                  onChanged: (v) {
                    final c = cfg.copy()..lifeNailHeight = v;
                    controller.updateConfig(c);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: controller.resetConfigToDefault,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('釘を標準配置に戻す'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 設定パネル（初期弾数・台パターン・固定値の表示）。
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final GameController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _ballField;

  @override
  void initState() {
    super.initState();
    _ballField =
        TextEditingController(text: '${widget.controller.initialBallCount}');
  }

  @override
  void dispose() {
    _ballField.dispose();
    super.dispose();
  }

  void _apply() {
    final v = int.tryParse(_ballField.text.trim());
    if (v != null && v > 0) {
      widget.controller.setInitialBallCount(v);
      widget.controller.resetGame();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('初期弾数を $v に設定し、リセットしました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('玉数', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ballField,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: '初期弾数',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: _apply, child: const Text('適用してリセット')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '設定できるのは初期弾数のみです。リセットはいつでも何度でも行えます。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 32),
              Text('台パターン', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: BoardPattern.phase1Standard.id,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: BoardPattern.all
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: null, // Phase1 は1種類のみ
              ),
              const SizedBox(height: 8),
              Text(
                'Phase1 は「中央スロット＋左右の回転体＋下部のチューリップ＋左右の入賞穴」'
                'の1パターンに固定です。配置は「編集」モードでブロック単位に変更できます。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.controller.usingCustomLayout) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text('現在：カスタム台（編集モードで作成）を使用中',
                          style: TextStyle(color: Colors.orange)),
                    ),
                    OutlinedButton(
                      onPressed: () => widget.controller.applyLayout(null),
                      child: const Text('既定台へ戻す'),
                    ),
                  ],
                ),
              ],
              const Divider(height: 32),
              Text('入賞球（Phase1 固定値）',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _KV(k: 'チューリップ 賞球', v: '15 個'),
              const _KV(k: '入賞穴 賞球（左右とも）', v: '7 個'),
              const _KV(k: 'スロット 当たり（3つ揃い）', v: '20 個'),
              const _KV(k: 'スロット 大当たり（7揃い）', v: '100 個'),
              const _KV(k: 'ファウル玉', v: '持ち玉へ返却'),
              const _KV(k: '自動発射間隔', v: '0.5 秒'),
            ],
          ),
        );
      },
    );
  }
}

class _ConfigSlider extends StatelessWidget {
  const _ConfigSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label： ${value.toStringAsFixed(1)}'),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          divisions: ((max - min) * 2).round(),
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
