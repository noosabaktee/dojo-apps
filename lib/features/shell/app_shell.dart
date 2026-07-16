import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../services/local_notification_service.dart';
import '../../state/app_session.dart';
import '../attendance/attendance_screen.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../evaluations/evaluation_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../menu/menu_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/report_screen.dart';
import '../wfh/wfh_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.user,
    required this.session,
    required this.repository,
    required this.notifications,
    super.key,
  });

  final AppUser user;
  final AppSession session;
  final AppRepository repository;
  final LocalNotificationService notifications;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _pollTimer;
  Set<int>? _knownNotificationIds;

  List<_Destination> get _destinations {
    if (widget.user.isIntern) {
      return const [
        _Destination(
          'dashboard',
          'Beranda',
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        _Destination(
          'leaderboard',
          'Peringkat',
          Icons.emoji_events_outlined,
          Icons.emoji_events,
        ),
        _Destination(
          'attendance',
          'Absensi',
          Icons.fingerprint_outlined,
          Icons.fingerprint_rounded,
        ),
        _Destination(
          'calendar',
          'Kalender',
          Icons.calendar_month_outlined,
          Icons.calendar_month_rounded,
        ),
        _Destination(
          'menu',
          'Menu',
          Icons.grid_view_outlined,
          Icons.grid_view_rounded,
        ),
      ];
    }
    if (widget.user.isMentor) {
      return const [
        _Destination(
          'dashboard',
          'Beranda',
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        _Destination(
          'leaderboard',
          'Peringkat',
          Icons.emoji_events_outlined,
          Icons.emoji_events,
        ),
        _Destination(
          'calendar',
          'Kalender',
          Icons.calendar_month_outlined,
          Icons.calendar_month_rounded,
        ),
        _Destination(
          'evaluation',
          'Rapor',
          Icons.school_outlined,
          Icons.school_rounded,
        ),
        _Destination(
          'menu',
          'Menu',
          Icons.grid_view_outlined,
          Icons.grid_view_rounded,
        ),
      ];
    }
    return const [
      _Destination(
        'dashboard',
        'Beranda',
        Icons.home_outlined,
        Icons.home_rounded,
      ),
      _Destination(
        'leaderboard',
        'Peringkat',
        Icons.emoji_events_outlined,
        Icons.emoji_events,
      ),
      _Destination(
        'attendance',
        'Absensi',
        Icons.fact_check_outlined,
        Icons.fact_check_rounded,
      ),
      _Destination(
        'wfh',
        'WFH',
        Icons.home_work_outlined,
        Icons.home_work_rounded,
      ),
      _Destination(
        'menu',
        'Menu',
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.notifications.requestPermission();
      _pollNotifications();
    });
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollNotifications(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollNotifications();
  }

  Future<void> _pollNotifications() async {
    try {
      final items = await widget.repository.notifications(unreadOnly: true);
      final currentIds = items.map((item) => asInt(item['id'])).toSet();
      final known = _knownNotificationIds;
      _knownNotificationIds = currentIds;
      if (known == null) return;
      final newItems = items.where(
        (item) => !known.contains(asInt(item['id'])),
      );
      for (final item in newItems) {
        await widget.notifications.showServerUpdate(
          id: asInt(item['id']),
          title: item['title']?.toString() ?? 'Update Dojo',
          body: item['message']?.toString() ?? '',
          payload: item['link']?.toString(),
        );
      }
    } on ApiException {
      // Polling is opportunistic; feature screens still expose manual refresh.
    }
  }

  void _openFeature(String key) {
    final target = _destinations.indexWhere((item) => item.key == key);
    if (target >= 0) {
      setState(() => _index = target);
      return;
    }
    if (key == 'notifications') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsScreen(repository: widget.repository),
        ),
      );
      return;
    }
    if (key == 'profile') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            user: widget.user,
            session: widget.session,
            notifications: widget.notifications,
          ),
        ),
      );
      return;
    }
    final child = _featureFor(key);
    if (child == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(appBar: AppBar(toolbarHeight: 46), body: child),
      ),
    );
  }

  Widget? _featureFor(String key) => switch (key) {
    'attendance' => AttendanceScreen(
      user: widget.user,
      repository: widget.repository,
      notifications: widget.notifications,
    ),
    'calendar' => CalendarScreen(repository: widget.repository),
    'evaluation' => EvaluationScreen(
      user: widget.user,
      repository: widget.repository,
    ),
    'wfh' => WfhScreen(repository: widget.repository),
    'report' => ReportScreen(user: widget.user, repository: widget.repository),
    _ => null,
  };

  Widget _selectedPage() {
    final key = _destinations[_index].key;
    return switch (key) {
      'dashboard' => DashboardScreen(
        user: widget.user,
        repository: widget.repository,
        onOpenFeature: _openFeature,
        onOpenNotifications: () => _openFeature('notifications'),
      ),
      'leaderboard' => LeaderboardScreen(repository: widget.repository),
      'menu' => MenuScreen(user: widget.user, onOpen: _openFeature),
      _ => _featureFor(key)!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: List.generate(destinations.length, (index) {
            if (index != _index) return const SizedBox.shrink();
            return KeyedSubtree(
              key: ValueKey('${destinations[index].key}-${widget.user.id}'),
              child: _selectedPage(),
            );
          }),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.key, this.label, this.icon, this.selectedIcon);
  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
