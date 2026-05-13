import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AndroidPowerSettingsService {
  Future<void> showSetupDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Permission Setup'),
        content: const Text(
          'For reliable reminders, allow background activity and disable battery optimization for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppInfo();
            },
            child: const Text('Open App Info'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openBatteryOptimizationSettings();
            },
            child: const Text('Battery Settings'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openExactAlarmSettings();
            },
            child: const Text('Exact Alarm'),
          ),
        ],
      ),
    );
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  Future<void> openAppInfo() async {
    if (!Platform.isAndroid) return;
    final packageName = (await PackageInfo.fromPlatform()).packageName;
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$packageName',
    );
    await intent.launch();
  }

  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    final packageName = (await PackageInfo.fromPlatform()).packageName;
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      data: 'package:$packageName',
    );
    await intent.launch();
  }
}
