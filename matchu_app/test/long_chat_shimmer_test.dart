import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/views/chat/long_chat/long_chat_shimmer.dart';

void main() {
  testWidgets('initial long chat state uses shimmer instead of a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const LongChatHeaderShimmer()),
          body: const LongChatMessagesShimmer(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LongChatHeaderShimmer), findsOneWidget);
    expect(find.byType(LongChatMessagesShimmer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Dispose the infinite shimmer animation before the test finishes.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
