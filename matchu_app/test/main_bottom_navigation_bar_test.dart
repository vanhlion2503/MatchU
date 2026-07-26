import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/views/main/widgets/main_bottom_navigation_bar.dart';

void main() {
  testWidgets('shows the unread notification count on the Home icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainBottomNavigationBar(
            currentIndex: 0,
            isVisible: true,
            unreadCount: 0,
            notificationUnreadCount: 7,
            isHomeRefreshing: false,
            isHomeFeedScrolled: false,
            onTabSelected: (_) {},
            onCenterTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hides the Home badge when all notifications are read', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainBottomNavigationBar(
            currentIndex: 0,
            isVisible: true,
            unreadCount: 0,
            notificationUnreadCount: 0,
            isHomeRefreshing: false,
            isHomeFeedScrolled: false,
            onTabSelected: (_) {},
            onCenterTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
