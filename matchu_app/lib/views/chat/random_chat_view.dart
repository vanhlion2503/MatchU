import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/services/chat/matching_service.dart';
import 'package:matchu_app/views/chat/chat_widget/avatar_overlay_service.dart';
import 'package:matchu_app/widgets/chat_widget/ripple_animation_widget.dart';

class RandomChatView extends StatefulWidget {
  const RandomChatView({super.key});

  @override
  State<RandomChatView> createState() => _RandomChatViewState();
}

enum _GuideTab { overview, howTo, rules }

class _RandomChatViewState extends State<RandomChatView>
    with SingleTickerProviderStateMixin {
  static const Map<_GuideTab, _GuideSectionData> _guideSections = {
    _GuideTab.overview: _GuideSectionData(
      title: 'Giới thiệu tổng quan',
      summary:
          'MatchU ghép cặp ẩn danh theo tiêu chí của bạn và mở phòng chat tạm để làm quen nhanh.',
      icon: Iconsax.flash_1,
      bullets: [
        'Ghép cặp theo giới tính bạn chọn: Nam, Nữ hoặc Ngẫu nhiên.',
        'Mỗi phiên bắt đầu từ avatar ẩn danh để tăng an toàn khi làm quen.',
        'Tài khoản đã xác thực khuôn mặt dùng matching không giới hạn.',
      ],
    ),
    _GuideTab.howTo: _GuideSectionData(
      title: 'Cách chơi',
      summary: 'Làm theo 4 bước để bắt đầu trò chuyện và kết nối đúng người.',
      icon: Iconsax.play_circle,
      bullets: [
        'Bước 1: Chọn avatar ẩn danh của bạn.',
        'Bước 2: Chọn đối tượng muốn ghép (Nam/Nữ/Ngẫu nhiên).',
        'Bước 3: Nhấn nút Bắt đầu tìm kiếm và chờ hệ thống ghép cặp.',
        'Bước 4: Vào phòng chat tạm 7 phút để trò chuyện và quyết định tiếp tục.',
      ],
    ),
    _GuideTab.rules: _GuideSectionData(
      title: 'Luật chơi',
      summary:
          'Bộ luật áp dụng cho matching chat để đảm bảo công bằng và an toàn.',
      icon: Iconsax.shield_tick,
      bullets: [
        'Chỉ tính lượt khi ghép cặp thành công (không trừ lượt khi chỉ bấm tìm).',
        'Tài khoản chưa xác thực: tối đa 10 lượt ghép thành công/ngày, reset lúc 00:00.',
        'Nếu cả hai cùng thích nhau, hệ thống chuyển sang phòng chat lâu dài.',
        'Không spam, xúc phạm, quấy rối hoặc chia sẻ nội dung nhạy cảm.',
        'Vi phạm nhiều lần có thể bị cảnh báo, hạn chế hoặc khóa tính năng.',
      ],
    ),
  };

  late final AnimationController _rippleController;

  final controller = Get.find<MatchingController>();
  final anonAvatarC = Get.find<AnonymousAvatarController>();
  final _matchingService = MatchingService();
  final _box = GetStorage();

  String selectedTarget = 'random';
  MatchingQuotaPreview? _quotaPreview;
  bool _isLoadingQuota = true;
  bool _isStarting = false;
  bool _hasCheckedAutoRulesDialog = false;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Get.find<AuthController>();
      final user = auth.user;
      if (user != null) {
        await _matchingService.forceUnlock(user.uid);
      }
      await _refreshQuotaPreview();
      await _maybeAutoShowRulesDialog();
    });
  }

  @override
  void dispose() {
    AvatarOverlayService.hide();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _refreshQuotaPreview() async {
    final quota = await controller.getDailyQuotaPreview();
    if (!mounted) return;

    setState(() {
      _quotaPreview = quota;
      _isLoadingQuota = false;
    });
  }

  bool get _isOutOfQuota {
    final quota = _quotaPreview;
    if (_isLoadingQuota || quota == null || quota.isUnlimited) {
      return false;
    }
    return quota.remaining <= 0;
  }

  String _startButtonLabel() {
    if (_isStarting) {
      return 'Đang bắt đầu...';
    }
    if (_isLoadingQuota) {
      return 'Đang tải lượt...';
    }

    final quota = _quotaPreview;
    if (quota == null) {
      return 'Bắt đầu tìm kiếm';
    }
    if (quota.isUnlimited) {
      return 'Bắt đầu tìm kiếm';
    }
    if (quota.remaining <= 0) {
      return 'Hết lượt hôm nay • 0/${quota.limit}';
    }

    return 'Bắt đầu tìm kiếm • ${quota.remaining}/${quota.limit}';
  }

  Future<void> _showOutOfQuotaDialog() async {
    if (!mounted) return;

    final shouldVerify =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Hết lượt'),
              content: const Text(
                'Nếu muốn tiếp tục, hãy xác thực tài khoản để sử dụng không giới hạn.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Để sau'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Xác thực ngay'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldVerify) return;

    await Get.toNamed('/face-verification');
    await _refreshQuotaPreview();
  }

  String _rulesDialogStorageKey() {
    final uid = Get.find<AuthController>().user?.uid;
    if (uid == null || uid.isEmpty) {
      return 'matching_rules_hide_dialog';
    }
    return 'matching_rules_hide_dialog_$uid';
  }

  Future<void> _maybeAutoShowRulesDialog() async {
    if (_hasCheckedAutoRulesDialog || !mounted) {
      return;
    }
    _hasCheckedAutoRulesDialog = true;

    final shouldHide = _box.read(_rulesDialogStorageKey()) == true;
    if (shouldHide) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await showMatchingRulesDialog(context);
  }

  Future<void> showMatchingRulesDialog(BuildContext context) async {
    final theme = Theme.of(context);
    bool dontShowAgain = _box.read(_rulesDialogStorageKey()) == true;

    final updatedValue =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            bool localValue = dontShowAgain;

            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: Text(
                    'Hướng dẫn Chat Matching',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRulesDialogSection(
                            _guideSections[_GuideTab.overview]!,
                            theme,
                          ),
                          const SizedBox(height: 14),
                          _buildRulesDialogSection(
                            _guideSections[_GuideTab.howTo]!,
                            theme,
                          ),
                          const SizedBox(height: 14),
                          _buildRulesDialogSection(
                            _guideSections[_GuideTab.rules]!,
                            theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            // 👈 QUAN TRỌNG
                            child: InkWell(
                              onTap: () {
                                setStateDialog(() {
                                  localValue = !localValue;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: localValue,
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        localValue = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    // 👈 text được phép xuống dòng
                                    child: Text(
                                      'Không hiển thị lần sau nữa',
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed:
                                () =>
                                    Navigator.of(dialogContext).pop(localValue),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        dontShowAgain;

    await _box.write(_rulesDialogStorageKey(), updatedValue);
  }

  Future<void> _onStartPressed() async {
    if (_isStarting || _isLoadingQuota) return;

    if (_isOutOfQuota) {
      await _showOutOfQuotaDialog();
      return;
    }

    if (!anonAvatarC.isSelected) {
      Get.snackbar(
        'Thiếu avatar ẩn danh',
        'Vui lòng chọn avatar trước khi bắt đầu',
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      final latestQuota = await controller.getDailyQuotaPreview();
      if (!mounted) return;

      setState(() {
        _quotaPreview = latestQuota;
        _isLoadingQuota = false;
      });

      if (latestQuota != null &&
          !latestQuota.isUnlimited &&
          latestQuota.remaining <= 0) {
        await _showOutOfQuotaDialog();
        return;
      }

      controller.isMinimized.value = false;
      await Get.toNamed(
        '/matching',
        arguments: {
          'targetGender': selectedTarget,
          'anonymousAvatar': anonAvatarC.selectedAvatar.value,
        },
      );

      await _refreshQuotaPreview();
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.surface.withValues(alpha: 0.6),
            border: Border.all(color: color.outline.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: const Icon(Iconsax.info_circle, size: 22),
            onPressed: () {
              showMatchingRulesDialog(context);
            },
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text('100 trực tuyến', style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const contentMaxWidth = 560.0;

            final viewPadding = MediaQuery.viewPaddingOf(context);
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final bottomNavigationClearance = keyboardInset > 0 ? 16.0 : 96.0;
            final isCompactHeight = constraints.maxHeight < 700;
            final isNarrowWidth = constraints.maxWidth < 360;
            final horizontalPadding = isNarrowWidth ? 16.0 : 24.0;
            final topPadding = isCompactHeight ? 12.0 : 20.0;
            final sectionGap = isCompactHeight ? 12.0 : 18.0;
            final buttonHeight = isCompactHeight ? 54.0 : 60.0;
            final titleFontSize =
                isNarrowWidth
                    ? 24.0
                    : (constraints.maxWidth > 460 ? 30.0 : 27.0);
            final subtitleFontSize = isCompactHeight ? 16.0 : 18.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    viewPadding.bottom + bottomNavigationClearance,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntroSection(
                        theme,
                        titleFontSize: titleFontSize,
                        subtitleFontSize: subtitleFontSize,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, middleConstraints) {
                            final middleHeight = middleConstraints.maxHeight;
                            if (middleHeight < 240) {
                              return SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: middleHeight,
                                  ),
                                  child: _buildTargetSection(
                                    theme,
                                    compact: true,
                                  ),
                                ),
                              );
                            }

                            final middleGap =
                                middleHeight < 340 ? 10.0 : sectionGap;
                            final targetHeight =
                                (middleHeight * (isCompactHeight ? 0.34 : 0.3))
                                    .clamp(108.0, 132.0)
                                    .toDouble();
                            final avatarAreaHeight =
                                (middleHeight - targetHeight - middleGap)
                                    .clamp(120.0, middleHeight)
                                    .toDouble();
                            final rippleSize =
                                avatarAreaHeight.clamp(120.0, 250.0).toDouble();
                            final avatarRadius =
                                (rippleSize * 0.38)
                                    .clamp(38.0, 56.0)
                                    .toDouble();
                            final compactMiddle =
                                isCompactHeight || middleHeight < 420;

                            return Column(
                              children: [
                                SizedBox(
                                  height: avatarAreaHeight,
                                  child: Center(
                                    child: _buildAvatarStage(
                                      theme,
                                      rippleSize: rippleSize,
                                      avatarRadius: avatarRadius,
                                      compact: compactMiddle,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: targetHeight,
                                  child: _buildTargetSection(
                                    theme,
                                    compact: compactMiddle,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton(
                          onPressed:
                              (_isLoadingQuota || _isStarting)
                                  ? null
                                  : _onStartPressed,
                          child: Text(_startButtonLabel()),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroSection(
    ThemeData theme, {
    required double titleFontSize,
    required double subtitleFontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Làm quen ngay',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: titleFontSize,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kết nối ẩn danh.\nChủ động lộ diện khi bạn sẵn sàng.',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: subtitleFontSize,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarStage(
    ThemeData theme, {
    required double rippleSize,
    required double avatarRadius,
    required bool compact,
  }) {
    final color = theme.colorScheme;
    final ringSize = avatarRadius * 2 + (compact ? 14 : 18);
    final editBadgeSize = compact ? 22.0 : 24.0;

    return SizedBox(
      width: rippleSize,
      height: rippleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RippleAnimation(
            animation: _rippleController,
            color: color.primary,
            size: rippleSize,
          ),
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.primary, width: 3),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: () => AvatarOverlayService.show(context),
              radius: avatarRadius + 18,
              customBorder: const CircleBorder(),
              highlightShape: BoxShape.circle,
              splashColor: color.primary.withValues(alpha: 0.16),
              highlightColor: color.primary.withValues(alpha: 0.08),
              child: Obx(() {
                final key = anonAvatarC.selectedAvatar.value;
                final ImageProvider<Object> imageProvider =
                    key == null
                        ? const AssetImage('assets/anonymous/placeholder.png')
                        : AssetImage('assets/anonymous/$key.png');

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  reverseDuration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );

                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.92,
                          end: 1,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    key: ValueKey(key ?? 'placeholder'),
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: color.surface,
                        backgroundImage: imageProvider,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: editBadgeSize,
                          height: editBadgeSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.primary,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Iconsax.edit_2,
                            size: compact ? 13 : 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection(ThemeData theme, {required bool compact}) {
    final color = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final outerPadding = compact ? 1.0 : 6.0;
    final contentGap = compact ? 10.0 : 16.0;
    final segmentPadding = compact ? 4.0 : 6.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Muốn tìm...',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              // fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: contentGap),
          Container(
            width: double.infinity,
            height: compact ? 46 : 60,
            padding: EdgeInsets.all(segmentPadding),
            decoration: BoxDecoration(
              color:
                  isLight
                      ? const Color(0xFFF1F4F7).withValues(alpha: 0.9)
                      : color.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _genderChip(theme, 'Nam', 'male', compact: compact),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _genderChip(theme, 'Nữ', 'female', compact: compact),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _genderChip(
                    theme,
                    'Ngẫu nhiên',
                    'random',
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesDialogSection(_GuideSectionData section, ThemeData theme) {
    final color = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 20, color: color.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          section.summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...section.bullets.map((line) => _buildGuideBullet(line, theme)),
      ],
    );
  }

  Widget _buildGuideBullet(String text, ThemeData theme) {
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 7, color: color.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _genderChip(
    ThemeData theme,
    String label,
    String value, {
    bool compact = false,
  }) {
    final color = theme.colorScheme;
    final selected = selectedTarget == value;
    final isLight = theme.brightness == Brightness.light;

    final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selected ? null : () => setState(() => selectedTarget = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color:
                selected
                    ? (isLight
                        ? const Color(0xFF2A2F36).withValues(alpha: 0.8)
                        : const Color.fromARGB(
                          255,
                          255,
                          255,
                          255,
                        ).withValues(alpha: 0.2))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: baseStyle.copyWith(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w600,
              color:
                  selected
                      ? Colors.white
                      : (isLight
                          ? const Color(0xFF2A2F36).withValues(alpha: 0.7)
                          : color.onSurface.withValues(alpha: 0.7)),
            ),
            child: Text(label, textAlign: TextAlign.center, maxLines: 2),
          ),
        ),
      ),
    );
  }
}

class _GuideSectionData {
  final String title;
  final String summary;
  final IconData icon;
  final List<String> bullets;

  const _GuideSectionData({
    required this.title,
    required this.summary,
    required this.icon,
    required this.bullets,
  });
}
