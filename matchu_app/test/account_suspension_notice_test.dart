import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/account_access/account_suspension_notice.dart';
import 'package:matchu_app/widgets/auth/account_suspension_dialog.dart';

void main() {
  test('parses suspension reason and Firestore expiry', () {
    final expiry = DateTime.utc(2026, 8, 2, 7, 30);
    final notice = AccountSuspensionNotice.fromUserData({
      'accountStatus': 'suspended',
      'suspension': {
        'reason': 'Phát tán nội dung vi phạm',
        'expiresAt': Timestamp.fromDate(expiry),
      },
    });

    expect(notice, isNotNull);
    expect(notice!.reason, 'Phát tán nội dung vi phạm');
    expect(
      notice.expiresAt?.millisecondsSinceEpoch,
      expiry.millisecondsSinceEpoch,
    );
    expect(
      notice.isActiveAt(expiry.subtract(const Duration(seconds: 1))),
      true,
    );
    expect(notice.isActiveAt(expiry), false);
  });

  test('ignores accounts that are not suspended', () {
    expect(
      AccountSuspensionNotice.fromUserData({
        'accountStatus': 'active',
        'suspension': {'reason': 'Old data'},
      }),
      isNull,
    );
  });

  testWidgets('popup shows suspension reason, expiry and confirmation', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSuspensionDialog(
            notice: AccountSuspensionNotice(
              reason: 'Vi phạm tiêu chuẩn cộng đồng',
              expiresAt: expiry,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tài khoản đang bị tạm khóa'), findsOneWidget);
    expect(find.text('Vi phạm tiêu chuẩn cộng đồng'), findsOneWidget);
    expect(find.textContaining('Tạm khóa đến'), findsOneWidget);
    expect(
      find.textContaining('vui lòng thoát hoàn toàn ứng dụng rồi mở lại'),
      findsOneWidget,
    );
    expect(find.text('Đã hiểu'), findsOneWidget);
  });
}
