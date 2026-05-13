import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/tutorial_screen.dart';
import 'widgets/app_logo.dart';
import 'theme/app_theme.dart';
import 'controllers/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.isRegistered<SessionController>()
        ? Get.find<SessionController>()
        : Get.put(SessionController());
    return Obx(
      () {
        final s = session.settings.value;
        final fallbackPrimary = AppTheme.resolveSeed(s.themeSeedKey);
        final primary = s.useCustomColors && s.customPrimaryColor != null

            ? Color(s.customPrimaryColor!)
            : fallbackPrimary;
        final secondary = s.useCustomColors && s.customSecondaryColor != null
            ? Color(s.customSecondaryColor!)
            : AppTheme.seedColors['emerald']!;
        return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Attendance Tracker',
        theme: AppTheme.light(
          seedColor: primary,
          secondaryColor: secondary,
          gradientEnabled: s.gradientEnabled,
        ),
        darkTheme: AppTheme.dark(
          seedColor: primary,
          secondaryColor: secondary,
          gradientEnabled: s.gradientEnabled,
        ),
        themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const AuthGate(),
      );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return Obx(() {
      if (session.bootstrapping.value) {
        return const _InitSplash();
      }
      if (session.bootstrapFailed.value) {
        return _BootstrapError(onRetry: () {
          session.bootstrap();
        });
      }
      if (!session.settings.value.onboardingCompleted) {
        return OnboardingScreen(
          current: session.settings.value,
          onComplete: session.completeOnboarding,
        );
      }
      if (!session.settings.value.tutorialCompleted) {
        return TutorialScreen(
          onDone: () {
            session.completeTutorial();
          },
          onStartInteractive: () {
            session.startInteractiveGuide();
          },
        );
      }
      if (session.syncingUserSettings.value) {
        return const _InitSplash();
      }
      final user = session.currentUser.value;
      if (user == null) {
        return const LoginScreen();
      }
      return HomeScreen(
        settings: session.settings.value,
        onSettingsChanged: session.updateSettings,
      );
    });
  }
}

class _InitSplash extends StatelessWidget {
  const _InitSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 90),
              const SizedBox(height: 14),
              Text(
                'Attendance Tracker',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final VoidCallback onRetry;
  const _BootstrapError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 10),
              const Text('Initialization failed'),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
