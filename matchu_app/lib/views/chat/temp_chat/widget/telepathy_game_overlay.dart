import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy_controller.dart';

class TelepathyGameOverlay extends StatefulWidget {
  final TempChatController controller;

  const TelepathyGameOverlay({
    super.key,
    required this.controller,
  });

  @override
  State<TelepathyGameOverlay> createState() => _TelepathyGameOverlayState();
}

class _TelepathyGameOverlayState extends State<TelepathyGameOverlay>
    with SingleTickerProviderStateMixin {
  static const _matchColor = Color(0xFFEC4899);
  static const _diffColor = Color(0xFFF97316);

  Worker? _feedbackWorker;
  AnimationController? _shakeController;
  Timer? _flashTimer;
  String? _lastFeedbackQuestionId;
  Color _flashColor = Colors.transparent;
  double _flashOpacity = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    final telepathy = widget.controller.telepathy;
    _feedbackWorker = everAll(
      [
        telepathy.status,
        telepathy.myAnswers,
        telepathy.otherAnswers,
        telepathy.currentIndex,
      ],
      (_) => _handleFeedback(),
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _feedbackWorker?.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  void _handleFeedback() {
    final telepathy = widget.controller.telepathy;
    if (telepathy.status.value != TelepathyStatus.playing) {
      _lastFeedbackQuestionId = null;
      return;
    }
    if (telepathy.questions.isEmpty) return;

    final index = telepathy.currentIndex.value
        .clamp(0, telepathy.questions.length - 1);
    final question = telepathy.questions[index];
    final my = telepathy.myAnswers[question.id];
    final other = telepathy.otherAnswers[question.id];

    if (my == null || other == null) return;
    if (_lastFeedbackQuestionId == question.id) return;

    _lastFeedbackQuestionId = question.id;
    _triggerFeedback(my == other);
  }

  void _triggerFeedback(bool match) {
    _showFlash(match ? _matchColor : _diffColor);

    if (match) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
      _shakeController?.forward(from: 0);
    }
  }

  void _showFlash(Color color) {
    _flashTimer?.cancel();
    setState(() {
      _flashColor = color;
      _flashOpacity = 0.35;
    });

    _flashTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _flashOpacity = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final telepathy = widget.controller.telepathy;

    return Obx(() {
      final status = telepathy.status.value;
      if (status != TelepathyStatus.countdown &&
          status != TelepathyStatus.playing) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xEE0B0B0B),
                    Color(0xCC0B0B0B),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(
              child: status == TelepathyStatus.countdown
                  ? _buildCountdown(context, telepathy)
                  : _buildGame(context, telepathy),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _flashOpacity,
                child: Container(color: _flashColor),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCountdown(
    BuildContext context,
    TelepathyController telepathy,
  ) {
    final theme = Theme.of(context);
    final seconds = telepathy.countdownSeconds.value;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Thần Giao Cách Cảm",
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            seconds.toString(),
            style: theme.textTheme.displayLarge?.copyWith(
              color: _matchColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Đang kết nối tâm trí...",
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(
    BuildContext context,
    TelepathyController telepathy,
  ) {
    final theme = Theme.of(context);

    if (telepathy.questions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final total = telepathy.questions.length;
    final index = telepathy.currentIndex.value.clamp(0, total - 1);
    final question = telepathy.questions[index];
    final answered = telepathy.myAnswers.containsKey(question.id);
    final seconds = telepathy.remainingSeconds.value;
    final disabled = answered;

    final stats = _computeMatchStats(telepathy);
    final progress = total == 0 ? 0.0 : (index + 1) / total;
    final matchRate = stats.answered == 0
        ? 0.0
        : stats.matched / stats.answered;

    final shakeAnim = _shakeController;

    return AnimatedBuilder(
      animation: shakeAnim ?? const AlwaysStoppedAnimation<double>(0),
      builder: (context, child) {
        final value = shakeAnim?.value ?? 0;
        final offset =
            math.sin(value * math.pi * 12) * 8 * (1 - value);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Câu ${index + 1}/$total",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "0:${seconds.toString().padLeft(2, '0')}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(_matchColor),
              ),
            ),
            const SizedBox(height: 16),
            _buildCompatibilityMeter(theme, matchRate, stats),
            const SizedBox(height: 18),
            Text(
              question.text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  _buildOptionCard(
                    label: question.left,
                    subtitle: "Chạm để chọn",
                    badge: "A",
                    icon: Icons.home_outlined,
                    selected:
                        telepathy.myAnswers[question.id] == question.left,
                    accent: _matchColor,
                    disabled: disabled,
                    onTap: () => telepathy.answer(question.left),
                  ),
                  const SizedBox(height: 14),
                  _buildOptionCard(
                    label: question.right,
                    subtitle: "Chạm để chọn",
                    badge: "B",
                    icon: Icons.terrain_outlined,
                    selected:
                        telepathy.myAnswers[question.id] == question.right,
                    accent: _diffColor,
                    disabled: disabled,
                    onTap: () => telepathy.answer(question.right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityMeter(
    ThemeData theme,
    double matchRate,
    _MatchStats stats,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              "Độ tương thích",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              "${(matchRate * 100).round()}%",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 8,
            color: Colors.white.withOpacity(0.12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: matchRate.clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_matchColor, _diffColor],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${stats.matched}/${stats.answered} câu trùng khớp",
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String label,
    required String subtitle,
    required String badge,
    required IconData icon,
    required bool selected,
    required bool disabled,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final borderColor =
        selected ? accent : Colors.white.withOpacity(0.18);
    final backgroundColor =
        selected ? accent.withOpacity(0.18) : Colors.white.withOpacity(0.08);
    final mutedColor = Colors.white.withOpacity(0.35);
    final textColor = Colors.white;
    final subtitleColor = Colors.white.withOpacity(0.7);
    final disabledOpacity = disabled && !selected ? 0.6 : 1.0;

    return Expanded(
      child: Opacity(
        opacity: disabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, size: 28, color: mutedColor),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _MatchStats _computeMatchStats(TelepathyController telepathy) {
    int matched = 0;
    int answered = 0;

    for (final question in telepathy.questions) {
      final my = telepathy.myAnswers[question.id];
      final other = telepathy.otherAnswers[question.id];
      if (my == null || other == null) continue;
      answered++;
      if (my == other) matched++;
    }

    return _MatchStats(matched: matched, answered: answered);
  }
}

class _MatchStats {
  final int matched;
  final int answered;

  const _MatchStats({
    required this.matched,
    required this.answered,
  });
}
