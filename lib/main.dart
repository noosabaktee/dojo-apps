import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'repositories/app_repository.dart';
import 'services/local_notification_service.dart';
import 'state/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final client = ApiClient();
  final repository = AppRepository(client);
  final session = AppSession(repository);
  client.onUnauthorized = session.expire;
  final notifications = LocalNotificationService();
  try {
    await notifications.initialize();
  } catch (_) {
    // The app remains usable if a desktop/web target has no notification host.
  }
  await session.bootstrap();
  runApp(
    DojoApp(
      session: session,
      repository: repository,
      notifications: notifications,
    ),
  );
}

class DojoApp extends StatelessWidget {
  const DojoApp({
    required this.session,
    required this.repository,
    required this.notifications,
    super.key,
  });

  final AppSession session;
  final AppRepository repository;
  final LocalNotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dojo Internship',
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
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064928), AppColors.primary, Color(0xFF4F982B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset(
                'assets/images/kdc-logo.png',
                width: 170,
                height: 54,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Internship Monitoring',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox.square(
              dimension: 25,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
