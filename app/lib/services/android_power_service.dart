import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

class AndroidPowerService {
  const AndroidPowerService();

  static const _channel = MethodChannel('undersound/power');

  bool get _isAndroid => Platform.isAndroid;

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!_isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'isBatteryOptimizationIgnored',
          ) ??
          true;
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Unable to read battery optimization state.',
        name: 'UnderSound.Power',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) {
      return;
    }
    await _invoke('requestIgnoreBatteryOptimizations');
  }

  Future<void> openBatterySettings() async {
    if (!_isAndroid) {
      return;
    }
    await _invoke('openBatterySettings');
  }

  Future<void> requestPostNotificationsPermission() async {
    if (!_isAndroid) {
      return;
    }
    await _invoke('requestPostNotificationsPermission');
  }

  Future<void> setWifiLockEnabled(bool enabled) async {
    if (!_isAndroid) {
      return;
    }
    await _invoke(enabled ? 'acquireWifiLock' : 'releaseWifiLock');
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Android power method failed: $method',
        name: 'UnderSound.Power',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
