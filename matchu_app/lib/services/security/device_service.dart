import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';

  static Future<String> getDeviceId() async {
    var id = await _storage.read(key: _deviceIdKey);
    if (id != null) return id;

    id = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }
}
