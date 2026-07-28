import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/controllers/system/network_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkController', () {
    test('stays online when a transient probe failure recovers', () async {
      var probeCount = 0;
      final controller = NetworkController(
        connectivityChecker:
            () async => const <ConnectivityResult>[ConnectivityResult.wifi],
        internetProbe: () async => ++probeCount > 1,
      );

      final connected = await controller.checkConnection();

      expect(connected, isTrue);
      expect(probeCount, 2);
      expect(controller.isOffline.value, isFalse);
      expect(controller.shouldShowOfflineOverlay.value, isFalse);
    });

    test('marks offline only after both reachability attempts fail', () async {
      var probeCount = 0;
      final controller = NetworkController(
        connectivityChecker:
            () async => const <ConnectivityResult>[ConnectivityResult.wifi],
        internetProbe: () async {
          probeCount++;
          return false;
        },
      );

      final connected = await controller.checkConnection();

      expect(connected, isFalse);
      expect(probeCount, 2);
      expect(controller.isOffline.value, isTrue);
      expect(controller.shouldShowOfflineOverlay.value, isTrue);
    });

    test('marks offline immediately when there is no transport', () async {
      var probeCount = 0;
      final controller = NetworkController(
        connectivityChecker:
            () async => const <ConnectivityResult>[ConnectivityResult.none],
        internetProbe: () async {
          probeCount++;
          return true;
        },
      );

      final connected = await controller.checkConnection();

      expect(connected, isFalse);
      expect(probeCount, 0);
      expect(controller.isOffline.value, isTrue);
      expect(controller.shouldShowOfflineOverlay.value, isTrue);
    });

    test(
      'does not invent an offline state when connectivity query fails',
      () async {
        final controller = NetworkController(
          connectivityChecker:
              () async => throw StateError('temporary failure'),
          internetProbe: () async => false,
        );

        final connected = await controller.checkConnection();

        expect(connected, isTrue);
        expect(controller.isOffline.value, isFalse);
        expect(controller.shouldShowOfflineOverlay.value, isFalse);
      },
    );

    test(
      'shares an in-flight check instead of returning a stale state',
      () async {
        final probeCompleter = Completer<bool>();
        var probeCount = 0;
        final controller = NetworkController(
          connectivityChecker:
              () async => const <ConnectivityResult>[ConnectivityResult.wifi],
          internetProbe: () {
            probeCount++;
            return probeCompleter.future;
          },
        );

        final firstCheck = controller.checkConnection();
        final secondCheck = controller.checkConnection();
        probeCompleter.complete(true);

        expect(await firstCheck, isTrue);
        expect(await secondCheck, isTrue);
        expect(probeCount, 1);
      },
    );
  });
}
