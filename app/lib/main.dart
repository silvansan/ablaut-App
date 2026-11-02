import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/ablaut_audio_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initFirebase();
  await AblautAudioService.instance.initialize();
  runApp(AblautApp(firebaseReady: firebaseReady));
}

/// Firebase config files are not committed, so builds without them
/// (iOS for now, CI, fresh clones) skip Firebase instead of crashing.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase not configured, skipping: $error');
    return false;
  }

  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
  return true;
}

class AblautApp extends StatelessWidget {
  const AblautApp({super.key, this.firebaseReady = false});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ablaut',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      navigatorObservers: [
        if (firebaseReady)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: const HomeScreen(),
    );
  }
}
