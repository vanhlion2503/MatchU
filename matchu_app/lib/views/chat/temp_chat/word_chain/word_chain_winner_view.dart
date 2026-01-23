import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/models/word_chain.dart';

import 'word_chain_reward_components.dart';
import 'word_chain_reward_data.dart';


enum _RewardInputMode { suggested, custom }

class WordChainRewardView extends StatefulWidget {
  final WordChainController wordChain;
  final bool isWinner;

  const WordChainRewardView({
    super.key,
    required this.wordChain,
    required this.isWinner,
  });

  @override
  State<WordChainRewardView> createState() => _WordChainRewardViewState();
}

class _WordChainRewardViewState extends State<WordChainRewardView> {
  static const int _maxQuestionLength = 120;
  static const int _maxAnswerLength = 200;
  static const List<String> _blockedTokens = [
    'sex',
    'xxx',
    'nude',
    'onlyfans',
  ];

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _questionFocus = FocusNode();
  final FocusNode _answerFocus = FocusNode();
  Worker? _phaseWorker;
  _RewardInputMode _inputMode = _RewardInputMode.suggested;
  WordChainRewardQuestion? _selectedPreset;
  bool _sendingQuestion = false;
  bool _sendingAnswer = false;
  bool _reviewing = false;
  bool _exiting = false;

  bool get _isWinner => widget.isWinner;
  bool get _isLoser => !widget.isWinner;

  @override
  void initState() {
    super.initState();
    _phaseWorker = ever<WordChainRewardPhase>(
      widget.wordChain.rewardPhase,
      _handlePhaseChange,
    );
  }

  void _handlePhaseChange(WordChainRewardPhase phase) {
    if (!mounted) return;
    setState(() {
      if (phase != WordChainRewardPhase.asking) {
        _questionController.clear();
        _selectedPreset = null;
        _inputMode = _RewardInputMode.suggested;
        _sendingQuestion = false;
        _exiting = false;
        _questionFocus.unfocus();
      }
      if (phase != WordChainRewardPhase.answering) {
        _answerController.clear();
        _sendingAnswer = false;
        _answerFocus.unfocus();
      }
      if (phase != WordChainRewardPhase.reviewing) {
        _reviewing = false;
      }
    });
  }

  @override
  void dispose() {
    _phaseWorker?.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _questionFocus.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  String? _validateRewardText(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Nội dung không được để trống.';
    }
    if (trimmed.length > maxLength) {
      return 'Vượt quá $maxLength ký tự.';
    }
    final lower = trimmed.toLowerCase();
    for (final token in _blockedTokens) {
      if (lower.contains(token)) {
        return 'Nội dung không phù hợp, hãy chỉnh sửa.';
      }
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    HapticFeedback.mediumImpact();
  }

  Future<void> _submitQuestion() async {
    if (_sendingQuestion) return;
    final question = _inputMode == _RewardInputMode.suggested
        ? (_selectedPreset?.prompt ?? '')
        : _questionController.text;

    final error = _validateRewardText(question, _maxQuestionLength);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _sendingQuestion = true);
    await widget.wordChain.submitRewardQuestion(
      question: question,
      presetId: _selectedPreset?.id,
    );
    if (!mounted) return;
    setState(() => _sendingQuestion = false);
  }

  Future<void> _submitAnswer() async {
    if (_sendingAnswer) return;
    final answer = _answerController.text;
    final error = _validateRewardText(answer, _maxAnswerLength);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _sendingAnswer = true);
    await widget.wordChain.submitRewardAnswer(answer: answer);
    if (!mounted) return;
    setState(() => _sendingAnswer = false);
  }

  Future<void> _reviewAnswer(bool accept) async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    HapticFeedback.lightImpact();
    await widget.wordChain.reviewRewardAnswer(accept: accept);
    if (!mounted) return;
    setState(() => _reviewing = false);
  }

  Future<void> _exitReward() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    HapticFeedback.lightImpact();
    await widget.wordChain.exitReward(reason: 'winner_left');
    if (!mounted) return;
    setState(() => _exiting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final phase = widget.wordChain.rewardPhase.value;
      final question = widget.wordChain.rewardQuestion.value;
      final answer = widget.wordChain.rewardAnswer.value;
      final declineCount = widget.wordChain.rewardDeclineCount.value;
      final askSecondsLeft = widget.wordChain.rewardAskSecondsLeft.value;
      final answerSecondsLeft =
          widget.wordChain.rewardAnswerSecondsLeft.value;
      final secondsLeft = widget.wordChain.rewardReviewSecondsLeft.value;
      final autoReason = widget.wordChain.rewardAutoAcceptedReason.value;

      return SingleChildScrollView(
        key: const ValueKey('word_chain_reward'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RewardHeroCard(isWinner: _isWinner),
            const SizedBox(height: 14),
            RewardStepIndicator(phase: phase),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildPhaseContent(
                theme: theme,
                phase: phase,
                question: question,
                answer: answer,
                declineCount: declineCount,
                askSecondsLeft: askSecondsLeft,
                answerSecondsLeft: answerSecondsLeft,
                secondsLeft: secondsLeft,
                autoReason: autoReason,
              ),
            ),
            const SizedBox(height: 16),
            const RewardMotto(),
          ],
        ),
      );
    });
  }

  Widget _buildPhaseContent({
    required ThemeData theme,
    required WordChainRewardPhase phase,
    required String question,
    required String answer,
    required int declineCount,
    required int askSecondsLeft,
    required int answerSecondsLeft,
    required int secondsLeft,
    required String? autoReason,
  }) {
    switch (phase) {
      case WordChainRewardPhase.asking:
        return _isWinner
            ? _buildQuestionComposer(theme, askSecondsLeft)
            : _buildWaitingQuestion(askSecondsLeft);
      case WordChainRewardPhase.answering:
        return _isLoser
            ? _buildAnswerComposer(
                theme,
                question,
                declineCount,
                answerSecondsLeft,
              )
            : _buildWaitingAnswer(
                theme,
                question,
                answerSecondsLeft,
              );
      case WordChainRewardPhase.reviewing:
        return _isWinner
            ? _buildReviewPanel(
                theme,
                question,
                answer,
                declineCount,
                secondsLeft,
              )
            : _buildReviewWaiting(
                theme,
                question,
                answer,
                declineCount,
                secondsLeft,
              );
      case WordChainRewardPhase.done:
        return _buildCompletion(theme, autoReason);
      case WordChainRewardPhase.idle:
        return const RewardWaitingCard(
          key: ValueKey('reward_idle'),
          icon: Icons.hourglass_empty,
          title: 'Đang chuẩn bị',
          message: 'Hệ thống đang khởi tạo cơ chế thưởng.',
        );
    }
  }

  Widget _buildQuestionComposer(ThemeData theme, int secondsLeft) {
    final canSubmit = _inputMode == _RewardInputMode.suggested
        ? _selectedPreset != null
        : _questionController.text.trim().isNotEmpty;

    return Container(
      key: const ValueKey('reward_asking'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 2 — Đặt câu hỏi',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn gợi ý an toàn hoặc tự nhập câu hỏi của bạn.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                showCheckmark: false,
                label: Text(
                  'Gợi ý',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900
                  )
                ),
                selected: _inputMode == _RewardInputMode.suggested,
                onSelected: (value) {
                  if (!value) return;
                  setState(() {
                    _inputMode = _RewardInputMode.suggested;
                    _questionFocus.unfocus();
                  });
                },
              ),
              ChoiceChip(
                showCheckmark: false,
                label: Text(
                  'Tự nhập',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900
                  )
                ),
                selected: _inputMode == _RewardInputMode.custom,
                onSelected: (value) {
                  if (!value) return;
                  setState(() {
                    _inputMode = _RewardInputMode.custom;
                    _selectedPreset = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _inputMode == _RewardInputMode.suggested
                ? Column(
                    key: const ValueKey('reward_suggested'),
                    children: kWordChainRewardQuestions.map((card) {
                      final selected = _selectedPreset?.id == card.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WordChainRewardQuestionTile(
                          card: card,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _selectedPreset = card;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  )
                : Column(
                    key: const ValueKey('reward_custom'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LengthRow(
                        label: 'Câu hỏi',
                        controller: _questionController,
                        maxLength: _maxQuestionLength,
                      ),
                      const SizedBox(height: 8),
                      RewardTextField(
                        controller: _questionController,
                        focusNode: _questionFocus,
                        hintText: 'Nhập câu hỏi bạn muốn hỏi...',
                        maxLength: _maxQuestionLength,
                        onChanged: (_) => setState(() {}),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          const SafetyNote(
            text: 'Nội dung sẽ được kiểm duyệt tự động.',
          ),
          if (secondsLeft > 0) ...[
            const SizedBox(height: 10),
            CountdownChip(secondsLeft: secondsLeft),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: canSubmit && !_sendingQuestion ? _submitQuestion : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero, // 👈 quan trọng
              minimumSize: const Size.fromHeight(48), // 👈 FIX CHÍNH
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _sendingQuestion
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 48, // 👈 cùng height với nút
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('text'),
                      height: 48,
                      child: Center(
                        child: Text('Gửi câu hỏi'),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sau khi gửi, câu hỏi sẽ được khóa và không thể chỉnh sửa.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed:
                !_sendingQuestion && !_exiting ? _exitReward : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.fromHeight(44),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _exiting
                  ? const SizedBox(
                      key: ValueKey('exiting'),
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('exit'),
                      height: 44,
                      child: Center(
                        child: Text('Thoát không đặt câu hỏi'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingQuestion(int secondsLeft) {
    return Column(
      key: const ValueKey('reward_wait_question'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RewardWaitingCard(
          icon: Icons.help_outline,
          title: 'Đối phương đang đặt câu hỏi',
          message: 'Hãy chuẩn bị để trả lời ngay khi nhận được.',
        ),
        if (secondsLeft > 0) ...[
          const SizedBox(height: 10),
          CountdownChip(secondsLeft: secondsLeft),
        ],
      ],
    );
  }

  Widget _buildAnswerComposer(
    ThemeData theme,
    String question,
    int declineCount,
    int secondsLeft,
  ) {
    final isFinalAttempt =
        declineCount >= WordChainController.rewardMaxDeclines;

    return Container(
      key: const ValueKey('reward_answering'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 3 — Trả lời câu hỏi',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          LockedQuestionCard(question: question),
          if (declineCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Đối phương đã yêu cầu trả lời lại ($declineCount/${WordChainController.rewardMaxDeclines}).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          LengthRow(
            label: 'Câu trả lời',
            controller: _answerController,
            maxLength: _maxAnswerLength,
          ),
          const SizedBox(height: 8),
          RewardTextField(
            controller: _answerController,
            focusNode: _answerFocus,
            hintText: 'Nhập câu trả lời của bạn...',
            maxLength: _maxAnswerLength,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SafetyNote(
            text: isFinalAttempt
                ? 'Lượt này sẽ được tự động chấp nhận để đảm bảo công bằng.'
                : 'Bạn bắt buộc trả lời để hoàn tất cơ chế thưởng.',
          ),
          if (secondsLeft > 0) ...[
            const SizedBox(height: 10),
            CountdownChip(secondsLeft: secondsLeft),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: !_sendingAnswer ? _submitAnswer : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero, // 👈 tránh bị Material bó
              minimumSize: const Size.fromHeight(48), // 👈 chiều cao cố định
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _sendingAnswer
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('text'),
                      height: 48,
                      child: Center(
                        child: Text('Gửi câu trả lời'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingAnswer(
    ThemeData theme,
    String question,
    int secondsLeft,
  ) {
    return Container(
      key: const ValueKey('reward_wait_answer'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang chờ câu trả lời',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          LockedQuestionCard(question: question),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Người kia cần trả lời trước khi bạn duyệt.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (secondsLeft > 0) ...[
            const SizedBox(height: 12),
            CountdownChip(secondsLeft: secondsLeft),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPanel(
    ThemeData theme,
    String question,
    String answer,
    int declineCount,
    int secondsLeft,
  ) {
    final remaining =
        WordChainController.rewardMaxDeclines - declineCount;
    final canDecline = remaining > 0;

    return Container(
      key: const ValueKey('reward_review'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 4 — Duyệt câu trả lời',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          LockedQuestionCard(question: question),
          const SizedBox(height: 10),
          AnswerCard(answer: answer),
          const SizedBox(height: 12),
          if (secondsLeft > 0)
            CountdownChip(
              secondsLeft: secondsLeft,
            ),
          const SizedBox(height: 10),
          Text(
            canDecline
                ? 'Bạn còn $remaining lần yêu cầu trả lời lại.'
                : 'Đã đạt giới hạn từ chối. Hệ thống sẽ tự động chấp nhận lần tiếp theo.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // ====== TRẢ LỜI LẠI ======
              Expanded(
                child: OutlinedButton(
                  onPressed: canDecline && !_reviewing
                      ? () => _reviewAnswer(false)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const SizedBox(
                    height: 48,
                    child: Center(
                      child: Text('Trả lời lại'),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ====== CHẤP NHẬN ======
              Expanded(
                child: ElevatedButton(
                  onPressed: !_reviewing ? () => _reviewAnswer(true) : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _reviewing
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            height: 48,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('text'),
                            height: 48,
                            child: Center(
                              child: Text('Chấp nhận'),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            'Nếu bạn không phản hồi, hệ thống sẽ tự động tiếp tục.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewWaiting(
    ThemeData theme,
    String question,
    String answer,
    int declineCount,
    int secondsLeft,
  ) {
    final remaining =
        WordChainController.rewardMaxDeclines - declineCount;

    return Container(
      key: const ValueKey('reward_wait_review'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang chờ duyệt',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          LockedQuestionCard(question: question),
          const SizedBox(height: 10),
          AnswerCard(answer: answer),
          const SizedBox(height: 12),
          if (secondsLeft > 0) CountdownChip(secondsLeft: secondsLeft),
          const SizedBox(height: 10),
          Text(
            remaining > 0
                ? 'Đối phương còn $remaining quyền yêu cầu trả lời lại.'
                : 'Hệ thống sẽ tự động chấp nhận nếu vượt quá giới hạn.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletion(ThemeData theme, String? autoReason) {
    final message = autoReason == 'timeout'
        ? 'Hệ thống đã tự động tiếp tục để đảm bảo trải nghiệm cho cả hai.'
        : autoReason == 'max_declines'
            ? 'Hệ thống tự động chấp nhận để đảm bảo công bằng cho cả hai.'
            : 'Cơ chế thưởng đã hoàn tất. Bạn có thể tiếp tục trò chuyện.';

    return Container(
      key: const ValueKey('reward_done'),
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Column(
        children: [
          Icon(
            Icons.verified,
            size: 36,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Hoàn tất',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
