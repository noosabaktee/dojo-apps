import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/formatters.dart';
import 'core/session_navigation.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'repositories/app_repository.dart';
import 'services/local_notification_service.dart';
import 'state/app_session.dart';
import 'widgets/common.dart';
import 'widgets/dojo_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeJakartaTimezone();
  await initializeDateFormatting('id_ID');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final client = ApiClient();
  final repository = AppRepository(client);
  final session = AppSession(repository);
  final navigatorKey = GlobalKey<NavigatorState>();
  var isExpiringSession = false;
  client.onUnauthorized = () {
    if (isExpiringSession) return;
    isExpiringSession = true;
    unawaited(
      expireSessionSafely(
        navigatorKey: navigatorKey,
        session: session,
      ).whenComplete(() => isExpiringSession = false),
    );
  };

  final notifications = LocalNotificationService();
  runApp(
    DojoApp(
      session: session,
      repository: repository,
      notifications: notifications,
      navigatorKey: navigatorKey,
    ),
  );
  unawaited(
    notifications.initialize().catchError((_) {
      // The app remains usable if a target has no notification host.
    }),
  );
  await session.bootstrap(minimumDuration: const Duration(milliseconds: 1350));
}

class DojoApp extends StatelessWidget {
  const DojoApp({
    required this.session,
    required this.repository,
    required this.notifications,
    required this.navigatorKey,
    super.key,
  });

  final AppSession session;
  final AppRepository repository;
  final LocalNotificationService notifications;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Dojo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          if (session.isBootstrapping) return const _SplashScreen();
          final user = session.user;
          if (user == null) return LoginScreen(session: session);
          return AppShell(
            user: user,
            session: session,
            repository: repository,
            notifications: notifications,
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppPageBackground(
      variant: 1,
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .92, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: Opacity(opacity: scale.clamp(0, 1), child: child),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F00351D),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const DojoLogoMark(size: 82),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Dojo',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontSize: 31,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Daily operation and journey overview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SplashFeatureCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Smarter operation. Better journey.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Monitor, track, notify, and collaborate in one place.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 132,
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                        backgroundColor: Color(0xFFDDE8DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SplashFeatureCard extends StatelessWidget {
  const _SplashFeatureCard();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF3F8B36)],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x29006838),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _SplashFeature(icon: Icons.monitor_heart_outlined, label: 'Monitor'),
        _SplashFeature(icon: Icons.route_outlined, label: 'Track'),
        _SplashFeature(
          icon: Icons.notifications_active_outlined,
          label: 'Notify',
        ),
        _SplashFeature(icon: Icons.groups_2_outlined, label: 'Team'),
      ],
    ),
  );
}

class _SplashFeature extends StatelessWidget {
  const _SplashFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
