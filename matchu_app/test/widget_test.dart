import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/system/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          return Directory.systemTemp.path;
        });
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
    Get.reset();
  });

  testWidgets('ThemeController defaults to light mode', (
    WidgetTester tester,
  ) async {
    final controller = Get.put(ThemeController());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const SizedBox.shrink(),
      ),
    );

    expect(controller.currentTheme, ThemeMode.light);
    expect(GetStorage().read('themeMode'), isNull);
  });

  testWidgets('ThemeController persists dark mode changes', (
    WidgetTester tester,
  ) async {
    final controller = Get.put(ThemeController());

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const SizedBox.shrink(),
      ),
    );

    controller.setDark();
    await tester.pumpAndSettle();

    expect(controller.currentTheme, ThemeMode.dark);
    expect(GetStorage().read('themeMode'), 'dark');
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });
}
