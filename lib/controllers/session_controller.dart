import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';

class SessionController extends GetxController {
  final SettingsService _settingsService = SettingsService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  final Rx<AppSettings> settings = AppSettings().obs;
  final RxBool bootstrapping = true.obs;
  final RxBool bootstrapFailed = false.obs;
  final RxBool syncingUserSettings = false.obs;
  final Rxn<User> currentUser = Rxn<User>();

  StreamSubscription<User?>? _authSub;
  String? _lastUid;
  Timer? _cloudSaveDebounce;

  @override
  void onInit() {
    super.onInit();
    bootstrap();
  }

  Future<void> bootstrap() async {
    if (!bootstrapping.value) {
      bootstrapping.value = true;
    }
    bootstrapFailed.value = false;
    try {
      await Hive.initFlutter();
      await Hive.openBox('timetableBox');
      await _settingsService.init();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      try {
        await _notificationService.init();
      } catch (_) {
        // Notifications are optional at bootstrap; don't block app startup.
      }
      try {
        settings.value = _settingsService.load();
      } catch (_) {
        settings.value = AppSettings();
      }
      _listenAuth();
    } catch (e, st) {
      debugPrint('bootstrap failed: $e');
      debugPrintStack(stackTrace: st);
      bootstrapFailed.value = true;
    } finally {
      bootstrapping.value = false;
    }
  }

  void _listenAuth() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      currentUser.value = user;
      if (user == null) {
        _lastUid = null;
        syncingUserSettings.value = false;
        return;
      }
      await _firestoreService.upsertUserMetadata(user);
      if (_lastUid == user.uid) return;
      _lastUid = user.uid;
      await _syncSettingsForUser(user.uid);
    });
  }

  Future<void> completeOnboarding(AppSettings updated) async {
    final snapshot = AppSettings.fromMap(updated.toMap());
    await _settingsService.save(snapshot);
    settings.value = snapshot;
    settings.refresh();
    final user = currentUser.value;
    if (user != null) {
      await _firestoreService.saveSettings(user.uid, snapshot).catchError((_) {});
    }
  }

  Future<void> updateSettings(AppSettings updated) async {
    final snapshot = AppSettings.fromMap(updated.toMap());
    settings.value = snapshot;
    settings.refresh();
    await _settingsService.save(snapshot);
    final user = currentUser.value;
    if (user != null) {
      _cloudSaveDebounce?.cancel();
      _cloudSaveDebounce = Timer(const Duration(milliseconds: 500), () {
        _firestoreService.saveSettings(user.uid, snapshot).catchError((_) {});
      });
    }
  }

  Future<void> completeTutorial() async {
    final updated = AppSettings.fromMap(settings.value.toMap());
    updated.tutorialCompleted = true;
    updated.interactiveGuideStep = 0;
    await updateSettings(updated);
  }

  Future<void> startInteractiveGuide() async {
    final updated = AppSettings.fromMap(settings.value.toMap());
    updated.tutorialCompleted = true;
    updated.interactiveGuideEnabled = true;
    updated.interactiveGuideStep = 0;
    await updateSettings(updated);
  }

  Future<void> _syncSettingsForUser(String uid) async {
    syncingUserSettings.value = true;
    try {
      final cloud = await _firestoreService.loadSettings(uid);
      final effective = AppSettings.fromMap((cloud ?? settings.value).toMap());
      settings.value = effective;
      settings.refresh();
      await _settingsService.save(effective);
      await _firestoreService.saveSettings(uid, effective);
    } catch (_) {
      // Keep local settings active when cloud permissions/config are unavailable.
    } finally {
      syncingUserSettings.value = false;
    }
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _cloudSaveDebounce?.cancel();
    super.onClose();
  }
}
