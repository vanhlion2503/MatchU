import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/translations/localized_material.dart';

/// Shows the room-exit confirmation used by the regular chat action bar.
Future<void> confirmTempChatExit(
  BuildContext context,
  TempChatController controller,
) async {
  if (controller.hasLeft.value) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Thoát phòng'),
          content: const Text('Bạn có chắc muốn thoát phòng không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Thoát'),
            ),
          ],
        ),
  );

  if (confirmed == true) {
    await controller.leaveByDislike();
  }
}

/// Exit affordance displayed above a full-screen temp-chat game.
class TempChatGameExitButton extends StatefulWidget {
  const TempChatGameExitButton({super.key, required this.onExit});

  final Future<void> Function() onExit;

  @override
  State<TempChatGameExitButton> createState() => _TempChatGameExitButtonState();
}

class _TempChatGameExitButtonState extends State<TempChatGameExitButton> {
  bool _showingConfirmation = false;

  Future<void> _onPressed() async {
    if (_showingConfirmation) return;
    setState(() => _showingConfirmation = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: Icon(
                Icons.sports_esports_rounded,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
              title: const Text('Thoát trò chơi?'),
              content: const Text(
                'Ván chơi hiện tại sẽ kết thúc cho cả hai. Bạn vẫn ở lại phòng chat.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Tiếp tục chơi'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Thoát game'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        await widget.onExit();
      }
    } catch (error) {
      Get.snackbar(
        'Lỗi'.tr,
        'Không thể thoát trò chơi lúc này.'.tr,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } finally {
      if (mounted) {
        setState(() => _showingConfirmation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.96),
            scheme.surfaceContainerHighest.withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.square(
          dimension: 44,
          child: IconButton(
            tooltip: 'Thoát trò chơi'.tr,
            onPressed: _showingConfirmation ? null : _onPressed,
            icon:
                _showingConfirmation
                    ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.error,
                      ),
                    )
                    : Icon(Icons.close_rounded, size: 23, color: scheme.error),
          ),
        ),
      ),
    );
  }
}
