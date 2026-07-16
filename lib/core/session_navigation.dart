import 'package:flutter/material.dart';

import '../state/app_session.dart';

Future<void> expireSessionSafely({
  required GlobalKey<NavigatorState> navigatorKey,
  required AppSession session,
  Duration transitionDuration = const Duration(milliseconds: 350),
}) async {
  final navigator = navigatorKey.currentState;
  final hadTransientRoute = navigator?.canPop() ?? false;
  navigator?.popUntil((route) => route.isFirst);

  if (hadTransientRoute) {
    await Future<void>.delayed(transitionDuration);
  }
  session.expire();
}
