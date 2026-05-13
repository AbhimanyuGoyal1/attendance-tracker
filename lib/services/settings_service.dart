import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;

  static const _boxName = 'settingsBox';
  static const _key = 'app_settings_v1';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  AppSettings load() {
    final box = Hive.box(_boxName);
    final data = box.get(_key);
    if (data is Map) {
      return AppSettings.fromMap(data);
    }
    return AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    final box = Hive.box(_boxName);
    await box.put(_key, settings.toMap());
  }
}
