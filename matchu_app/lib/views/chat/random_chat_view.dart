import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
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
      return '🔍 Bắt đầu tìm kiếm';
    }
    if (quota.isUnlimited) {
      return '🔍 Bắt đầu tìm kiếm • Không giới hạn';
    }
    if (quota.remaining <= 0) {
      return 'Hết lượt hôm nay • 0/${quota.limit}';
    }

    return '🔍 Bắt đầu tìm kiếm • ${quota.remaining}/${quota.limit}';
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
                          Expanded( // 👈 QUAN TRỌNG
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
                                  Expanded( // 👈 text được phép xuống dòng
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
                            onPressed: () =>
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
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        actions: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.surface.withValues(alpha: 0.6),
                  border: Border.all(
                    color: color.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Iconsax.messages, size: 25),
                  onPressed: () => Get.toNamed('/chat-list'),
                ),
              ),
              Obx(() {
                final unreadC = Get.find<UnreadController>();
                if (unreadC.totalUnread.value == 0) return const SizedBox();

                return Positioned(
                  right: 10,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadC.totalUnread.value > 99
                          ? '99+'
                          : unreadC.totalUnread.value.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Trò chuyện ngay',
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kết nối ẩn danh. Chủ động \nlộ diện khi bạn sẵn sàng.',
                  style: theme.textTheme.bodyLarge,
                ),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RippleAnimation(
                        animation: _rippleController,
                        color: color.primary,
                        size: 250,
                      ),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color.primary, width: 3),
                        ),
                      ),
                      GestureDetector(
                        onTap: AvatarOverlayService.show,
                        child: Obx(() {
                          final key = anonAvatarC.selectedAvatar.value;

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: color.surface,
                                backgroundImage:
                                    key == null
                                        ? const AssetImage(
                                          'assets/anonymous/placeholder.png',
                                        )
                                        : AssetImage(
                                          'assets/anonymous/$key.png',
                                        ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.primary,
                                    border: Border.all(
                                      color: theme.scaffoldBackgroundColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Iconsax.edit_2,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Muốn tìm…',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        isLight
                            ? const Color(0xFFF1F4F7).withValues(alpha: 0.65)
                            : color.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _genderChip(theme, 'Nam', 'male')),
                      const SizedBox(width: 8),
                      Expanded(child: _genderChip(theme, 'Nữ', 'female')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _genderChip(theme, 'Ngẫu nhiên', 'random'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed:
                        (_isLoadingQuota || _isStarting)
                            ? null
                            : _onStartPressed,
                    child: Text(_startButtonLabel()),
                  ),
                ),
              ],
            ),
          ),
        ),
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

  Widget _genderChip(ThemeData theme, String label, String value) {
    final color = theme.colorScheme;
    final selected = selectedTarget == value;
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selectedTarget = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
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
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color:
                selected
                    ? Colors.white
                    : (isLight
                        ? const Color(0xFF2A2F36).withValues(alpha: 0.7)
                        : color.onSurface.withValues(alpha: 0.7)),
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
