import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/views/chat/chat_widget/avatar_overlay_service.dart';

import 'avatar_carousel.dart';

class AnonymousAvatarSelector extends StatefulWidget {
  const AnonymousAvatarSelector({super.key});

  @override
  State<AnonymousAvatarSelector> createState() =>
      _AnonymousAvatarSelectorState();
}

class _AnonymousAvatarSelectorState extends State<AnonymousAvatarSelector> {
  final c = Get.find<AnonymousAvatarController>();
  late String? _initialAvatar;
  late String? _draftAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialAvatar = c.selectedAvatar.value;
    _draftAvatar = c.selectedAvatar.value;
  }

  bool get _hasChanges => _draftAvatar != _initialAvatar;

  void _syncDraftWithAvatars(List<String> avatars) {
    if (avatars.isEmpty) return;
    if (_draftAvatar != null && avatars.contains(_draftAvatar)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || avatars.isEmpty) return;
      setState(() {
        _draftAvatar = avatars.first;
      });
    });
  }

  void _onAvatarChanged(String avatarKey) {
    if (_draftAvatar == avatarKey) return;
    setState(() {
      _draftAvatar = avatarKey;
    });
  }

  void _close() {
    AvatarOverlayService.hide();
  }

  Future<void> _onSavePressed() async {
    if (_isSaving) return;
    final avatarKey = _draftAvatar;
    if (avatarKey == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_hasChanges) {
        await c.selectAndSave(avatarKey);
        _initialAvatar = avatarKey;
      }
      if (mounted) {
        _close();
      }
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'Không thể lưu avatar',
        'Vui lòng thử lại.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Iconsax.arrow_left_2,
              size: 28,
              color: Colors.white,
            ),
            onPressed: _close,
          ),
          title: Text(
            'Chọn Avatar',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          final avatars = c.avatars;
          _syncDraftWithAvatars(avatars);

          return Column(
            children: [
              const SizedBox(height: 16),
              AvatarCarousel(
                selectedAvatar: _draftAvatar,
                onChanged: _onAvatarChanged,
              ),
              const SizedBox(height: 16),
              Text(
                'Vuốt ngang để thay đổi',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              (_isSaving || _draftAvatar == null)
                                  ? null
                                  : _onSavePressed,
                          child:
                              _isSaving
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color.onPrimary,
                                      ),
                                    ),
                                  )
                                  : Text(_hasChanges ? 'Lưu thay đổi' : 'Xong'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
