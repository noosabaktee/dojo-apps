import 'package:dojo/core/api_client.dart';
import 'package:dojo/core/session_navigation.dart';
import 'package:dojo/models/app_user.dart';
import 'package:dojo/repositories/app_repository.dart';
import 'package:dojo/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'closes dialogs before rebuilding the app for an expired session',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final session = AppSession(AppRepository(ApiClient()))
        ..isBootstrapping = false
        ..user = const AppUser(
          id: 1,
          email: 'intern@example.com',
          role: 'Intern',
          name: 'Dojo Intern',
        );
      bool? couldPopWhenSessionExpired;
      session.addListener(() {
        if (session.user == null) {
          couldPopWhenSessionExpired = navigatorKey.currentState?.canPop();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: AnimatedBuilder(
            animation: session,
            builder: (context, _) {
              if (session.user == null) {
                return const Scaffold(body: Text('Login Dojo'));
              }
              return Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const AlertDialog(title: Text('Dialog pengajuan')),
                    ),
                    child: const Text('Buka dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog pengajuan'), findsOneWidget);

      final expiry = expireSessionSafely(
        navigatorKey: navigatorKey,
        session: session,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await expiry;
      await tester.pumpAndSettle();

      expect(couldPopWhenSessionExpired, isFalse);
      expect(find.text('Dialog pengajuan'), findsNothing);
      expect(find.text('Login Dojo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
