import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/temp_room_extension.dart';

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
}
