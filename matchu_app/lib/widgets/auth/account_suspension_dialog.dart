import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/account_access/account_suspension_notice.dart';

class AccountSuspensionDialog extends StatelessWidget {
  const AccountSuspensionDialog({required this.notice, super.key});

  final AccountSuspensionNotice notice;

  static Future<void> show(AccountSuspensionNotice notice) async {
    await Get.dialog<void>(
      AccountSuspensionDialog(notice: notice),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: colors.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_clock_outlined,
            color: colors.onErrorContainer,
            size: 30,
          ),
        ),
        title: const Text(
          'Tài khoản đang bị tạm khóa',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.expiryMessage,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(
              'Lý do',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 5),
            Text(notice.displayReason),
            const SizedBox(height: 14),
            Text(
              'Bạn có thể đăng nhập lại sau khi thời hạn tạm khóa kết thúc.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(
              'Nếu không thể đăng nhập bằng tài khoản khác, vui lòng thoát hoàn toàn ứng dụng rồi mở lại.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: Get.back<void>,
              child: const Text('Đã hiểu'),
            ),
          ),
        ],
      ),
    );
  }
}
