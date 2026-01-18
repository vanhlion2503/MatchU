import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy_controller.dart';
import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/models/telepathy_result.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_motion.dart';

class TelepathyResultOverlay extends StatefulWidget {
  final TempChatController controller;

  const TelepathyResultOverlay({
    super.key,
    required this.controller,
  });

  @override
  State<TelepathyResultOverlay> createState() =>
      _TelepathyResultOverlayState();
}

class _TelepathyResultOverlayState extends State<TelepathyResultOverlay>
    with SingleTickerProviderStateMixin {
  bool _showOpponentAnswers = false;
  Worker? _overlayWorker;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _overlayWorker =
        ever(widget.controller.telepathy.showResultOverlay, (show) {
      if (show == true && mounted) {
        setState(() => _showOpponentAnswers = false);

        _pulseController.forward(from: 0);
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: motionBase, // hoặc motionSlow
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _overlayWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telepathy = widget.controller.telepathy;

    return Obx(() {
      if (!telepathy.showResultOverlay.value) {
        return const SizedBox.shrink();
      }

      final result = telepathy.result.value;
      final aiStatus = telepathy.aiInsightStatus.value;
      final aiText = telepathy.aiInsightText.value;
      final isAiLoading = aiStatus == "pending";
      final isAiError = aiStatus == "error";
      if (result == null) return const SizedBox.shrink();

      final accent = _accentForLevel(result.level);
      final scoreRatio = (result.score / 100).clamp(0.0, 1.0);
      final maxHeight = MediaQuery.of(context).size.height * 0.82;
      const double outerSize = 100;
      const double stroke = 10;
      const double innerPadding = 12;

      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.65),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Kết quả tương thích",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: outerSize,
                          height: outerSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // ===== VÒNG TRÒN NGOÀI =====
                              SizedBox(
                                width: outerSize,
                                height: outerSize,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: scoreRatio),
                                  duration: motionSlow,
                                  curve: curveEnter,
                                  builder: (_, value, __) {
                                    return CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: stroke,
                                      backgroundColor: accent.withOpacity(0.12),
                                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                                    );
                                  },
                                ),
                              ),

                              // ===== VÙNG CHỮ AN TOÀN BÊN TRONG =====
                              SizedBox(
                                width: outerSize - stroke * 2 - innerPadding * 2,
                                height: outerSize - stroke * 2 - innerPadding * 2,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ScaleTransition(
                                      scale: Tween(begin: 1.2, end: 1.0).animate(
                                        CurvedAnimation(
                                          parent: _pulseController,
                                          curve: curveFeedback,
                                        ),
                                      ),
                                      child: Text(
                                        "${result.score}%",
                                        style: theme.textTheme.displaySmall?.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),


                        const SizedBox(height: 24),
                        Text(
                          result.summaryText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                        // ================= AI INSIGHT =================
                        if (isAiLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "AI đang phân tích thêm…",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            
                                ),
                              ],
                            ),
                          ),

                        if (!isAiLoading && aiText != null)
                          Container(
                            margin: const EdgeInsets.only(top: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accent.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Nhận xét từ MatchU AI",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  aiText!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (isAiError)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              "AI sẽ quay lại sau khi hai bạn trò chuyện thêm 😉",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        // ================= END AI INSIGHT =================

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatChip(
                              label: "Trùng khớp",
                              value: "${result.matchedCount}/${result.total}",
                              color: accent,
                            ),
                            const SizedBox(width: 10),
                            _StatChip(
                              label: "Tốc độ",
                              value: "15s",
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showOpponentAnswers = !_showOpponentAnswers;
                            });
                          },
                          icon: Icon(
                            _showOpponentAnswers
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _showOpponentAnswers
                                ? "Ẩn đáp án đối phương"
                                : "Xem đáp án đối phương",
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showOpponentAnswers
                              ? _AnswerList(
                                  questions: telepathy.questions,
                                  myAnswers: telepathy.myAnswers,
                                  otherAnswers: telepathy.otherAnswers,
                                  accent: accent,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () =>
                              telepathy.showResultOverlay.value = false,
                          child: const Text("Quay lại cuộc trò chuyện"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Color _accentForLevel(TelepathyLevel level) {
    switch (level) {
      case TelepathyLevel.high:
        return const Color(0xFFEC4899);
      case TelepathyLevel.medium:
        return const Color(0xFFF97316);
      case TelepathyLevel.low:
        return const Color(0xFF38BDF8);
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerList extends StatelessWidget {
  final List<TelepathyQuestion> questions;
  final Map<String, String> myAnswers;
  final Map<String, String> otherAnswers;
  final Color accent;

  const _AnswerList({
    required this.questions,
    required this.myAnswers,
    required this.otherAnswers,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (questions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          "Chưa có dữ liệu câu hỏi.",
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          for (int i = 0; i < questions.length; i++) ...[
            _AnswerItem(
              index: i + 1,
              question: questions[i],
              myAnswer: myAnswers[questions[i].id],
              otherAnswer: otherAnswers[questions[i].id],
              accent: accent,
            ),
            if (i != questions.length - 1)
              const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _AnswerItem extends StatelessWidget {
  final int index;
  final TelepathyQuestion question;
  final String? myAnswer;
  final String? otherAnswer;
  final Color accent;

  const _AnswerItem({
    required this.index,
    required this.question,
    required this.myAnswer,
    required this.otherAnswer,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Câu $index: ${question.text}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AnswerChip(
              label: "Bạn",
              value: myAnswer ?? "Chưa trả lời",
              color: theme.colorScheme.primary,
            ),
            _AnswerChip(
              label: "Đối phương",
              value: otherAnswer ?? "Chưa trả lời",
              color: accent,
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnswerChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
