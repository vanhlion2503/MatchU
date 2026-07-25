import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/temp_room_extension.dart';
import 'package:matchu_app/widgets/temp_room_extension_overlay.dart';

void main() {
  test('extension appears only during the final minute', () {
    expect(
      TempRoomExtensionPolicy.isAvailable(
        remainingSeconds: 60,
        extensionCount: 0,
        isActive: true,
      ),
      isTrue,
    );
    expect(
      TempRoomExtensionPolicy.isAvailable(
        remainingSeconds: 61,
        extensionCount: 0,
        isActive: true,
      ),
      isFalse,
    );
    expect(
      TempRoomExtensionPolicy.isAvailable(
        remainingSeconds: 0,
        extensionCount: 0,
        isActive: true,
      ),
      isFalse,
    );
  });

  test('extension is unavailable after two uses or after room end', () {
    expect(
      TempRoomExtensionPolicy.isAvailable(
        remainingSeconds: 30,
        extensionCount: TempRoomExtensionPolicy.maxExtensions,
        isActive: true,
      ),
      isFalse,
    );
    expect(
      TempRoomExtensionPolicy.isAvailable(
        remainingSeconds: 30,
        extensionCount: 1,
        isActive: false,
      ),
      isFalse,
    );
  });

  testWidgets('shared extension overlay can collapse and confirm', (
    tester,
  ) async {
    var extended = false;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TempRoomExtensionOverlay(
                isVisible: true,
                remainingSeconds: 45,
                extensionCount: 0,
                isLoading: false,
                onExtend: () async => extended = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Muốn trò chuyện thêm 5 phút?'), findsOneWidget);
    await tester.tap(find.text('Tạm ẩn'));
    await tester.pumpAndSettle();
    expect(find.text('00:45'), findsOneWidget);

    await tester.tap(find.text('00:45'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gia hạn • 1 gem'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm 5 phút?'), findsOneWidget);

    await tester.tap(find.text('Dùng 1 gem'));
    await tester.pumpAndSettle();
    expect(extended, isTrue);
  });
}
