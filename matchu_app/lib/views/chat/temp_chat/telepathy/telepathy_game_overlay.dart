import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_motion.dart';

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
    with TickerProviderStateMixin {
  static const _matchColor = Color(0xFFEC4899);
  static const _diffColor = Color(0xFFF97316);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnonymousAvatarController _avatarController;
  late final AnimationController _questionEnterController;
  late final Animation<double> _questionOpacity;
  late final Animation<double> _questionOffset;


  Worker? _feedbackWorker;
  AnimationController? _shakeController;
  Timer? _flashTimer;
  String? _lastFeedbackQuestionId;
  Color _flashColor = Colors.transparent;
  double _flashOpacity = 0;
  Worker? _countdownWorker;

  @override
  void initState() {
    super.initState();

    _avatarController = Get.find<AnonymousAvatarController>();

    _questionEnterController = AnimationController(
      vsync: this,
      duration: motionBase,
    );

    _questionOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _questionEnterController,
        curve: curveEnter,
      ),
    );

    _questionOffset = Tween(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _questionEnterController,
        curve: curveEnter,
      ),
    );


    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutBack,
    );

    final telepathy = widget.controller.telepathy;

    // ✅ WORKER 1: feedback (bạn đã có)
    _feedbackWorker = everAll(
      [
        telepathy.status,
        telepathy.myAnswers,
        telepathy.otherAnswers,
        telepathy.currentIndex,
      ],
      (_) => _handleFeedback(),
    );

    // ✅ WORKER 2: reset feedback khi sang câu mới
    ever<int>(telepathy.currentIndex, (_) {
      _lastFeedbackQuestionId = null;
      _questionEnterController.forward(from: 0);
    });

    _countdownWorker = ever<TelepathyStatus>(
      widget.controller.telepathy.status,
      (status) {
        if (status == TelepathyStatus.countdown) {
          _pulseController.forward(from: 0);
        }
      },
    );

  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _feedbackWorker?.dispose();
    _shakeController?.dispose();
    _pulseController.dispose(); // ✅ THÊM
    _countdownWorker?.dispose();
    _questionEnterController.dispose();
    super.dispose();
  }


  void _handleFeedback() {
    final telepathy = widget.controller.telepathy;

    if (telepathy.status.value != TelepathyStatus.playing) return;
    if (telepathy.questions.isEmpty) return; // ✅ FIX QUAN TRỌNG

    final index = telepathy.currentIndex.value;

    if (index < 0 || index >= telepathy.questions.length) return; // ✅ CHẮN CUỐI

    final question = telepathy.questions[index];

    final my = telepathy.myAnswers[question.id];
    final other = telepathy.otherAnswers[question.id];

    if (my == null || other == null) return;
    if (_lastFeedbackQuestionId == question.id) return;

    _lastFeedbackQuestionId = question.id;
    _triggerFeedback(my == other);
  }



  void _triggerFeedback(bool match) {
    if (match) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);

      // ✨ pulse nhẹ khi trùng
      _pulseController.forward(from: 0);
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);

      // ✨ rung nhẹ khi khác
      _shakeController?.forward(from: 0);
    }

    // flash chỉ giữ rất nhẹ
    _showFlash(match ? _matchColor : _diffColor);
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
          status != TelepathyStatus.playing &&
          status != TelepathyStatus.revealing) {
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
          ScaleTransition(
            scale: Tween(begin: 1.4, end: 1.0).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: curveFeedback, // từ telepathy_motion.dart
              ),
            ),
            child: Text(
              seconds.toString(),
              style: theme.textTheme.displayLarge?.copyWith(
                color: _matchColor,
                fontWeight: FontWeight.w800,
              ),
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
    final disabled = answered || telepathy.status.value == TelepathyStatus.revealing;


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
            AnimatedBuilder(
              animation: _questionEnterController,
              builder: (_, __) {
                return Opacity(
                  opacity: _questionOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _questionOffset.value),
                    child: Text(
                      question.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOptionCard(
                    label: question.left,
                    subtitle: "Chạm để chọn",
                    badge: "A",
                    icon: Icons.home_outlined,
                    selected: telepathy.myAnswers[question.id] == question.left,
                    otherPicked: _otherPickedThis(
                      telepathy,
                      question.id,
                      question.left,
                    ),
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
                    selected: telepathy.myAnswers[question.id] == question.right,
                    otherPicked: _otherPickedThis(
                      telepathy,
                      question.id,
                      question.right,
                    ),
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
    required bool otherPicked,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final borderColor =
        selected ? accent : Colors.white.withOpacity(0.18);
    final backgroundColor =
        selected ? accent.withOpacity(0.18) : Colors.white.withOpacity(0.08);
    final disabledOpacity = disabled && !selected ? 0.6 : 1.0;

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.22,
      child: Opacity(
        opacity: disabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            onTapDown: (_) {
              if (!disabled) {
                _pulseController.forward(from: 0);
              }
            },
            borderRadius: BorderRadius.circular(22),
            child: ScaleTransition(
              scale: selected
                  ? Tween(begin: 1.0, end: 1.04).animate(
                      CurvedAnimation(
                        parent: _pulseController,
                        curve: curveFeedback,
                      ),
                    )
                  : const AlwaysStoppedAnimation(1),
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
                child: Stack(
                  children: [
                    // 🅰️🅱️ BADGE
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    // 👤 AVATAR CỦA MÌNH
                    Positioned(
                      top: 0,
                      right: 35,
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: AnonymousAvatar(
                          avatarKey: _avatarController.selectedAvatar.value,
                          radius: 14,
                        ),
                      ),
                    ),

                    // 👤 AVATAR ĐỐI PHƯƠNG
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: otherPicked ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: AnonymousAvatar(
                          avatarKey:
                              widget.controller.otherAnonymousAvatar.value,
                          radius: 14,
                        ),
                      ),
                    ),

                    // 📌 NỘI DUNG CHÍNH
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

bool _otherPickedThis(
  TelepathyController telepathy,
  String questionId,
  String value,
) {
  return telepathy.otherAnswers[questionId] == value;
}