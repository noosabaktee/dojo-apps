import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.user,
    required this.repository,
    required this.onOpenFeature,
    required this.onOpenNotifications,
    super.key,
  });

  final AppUser user;
  final AppRepository repository;
  final ValueChanged<String> onOpenFeature;
  final VoidCallback onOpenNotifications;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _attendance;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await widget.repository.dashboard();
      Map<String, dynamic>? attendance;
      if (widget.user.isIntern) {
        attendance = await widget.repository.attendance(perPage: 7);
      }
      if (!mounted) return;
      setState(() {
        _data = dashboard;
        _attendance = attendance;
      });
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const LoadingList();
    if (_error != null && _data == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final data = _data ?? const <String, dynamic>{};
    final events = asMapList(data['upcoming_calendar_sharings']);
    final leaders = asMapList(data['leaderboard']);
    final today = asMap(_attendance?['today']);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PagePadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.user.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: widget.onOpenNotifications,
                        icon: const Icon(Icons.notifications_none_rounded),
                        tooltip: 'Notifikasi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _HeroCard(
                    user: widget.user,
                    today: today,
                    onTap: () => widget.onOpenFeature(
                      widget.user.isIntern ? 'attendance' : 'evaluation',
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionHeading(title: 'Ringkasan hari ini'),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: widget.user.isIntern
                        ? [
                            MetricCard(
                              label: 'Project aktif',
                              value: compactNumber(data['active_projects']),
                              icon: Icons.work_outline_rounded,
                              color: const Color(0xFF2563EB),
                            ),
                            MetricCard(
                              label: 'Progress rata-rata',
                              value:
                                  '${asDouble(data['average_progress']).toStringAsFixed(1)}%',
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF8B5CF6),
                            ),
                            MetricCard(
                              label: 'Rapor selesai',
                              value: compactNumber(data['completed_reports']),
                              icon: Icons.school_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                            MetricCard(
                              label: 'Achievement',
                              value: compactNumber(data['achievements']),
                              icon: Icons.workspace_premium_outlined,
                            ),
                          ]
                        : [
                            MetricCard(
                              label: 'Intern aktif',
                              value: compactNumber(data['total_interns']),
                              icon: Icons.groups_2_outlined,
                            ),
                            MetricCard(
                              label: 'Project aktif',
                              value: compactNumber(data['active_projects']),
                              icon: Icons.work_outline_rounded,
                              color: const Color(0xFF2563EB),
                            ),
                            MetricCard(
                              label: 'Progress rata-rata',
                              value:
                                  '${asDouble(data['average_progress']).toStringAsFixed(1)}%',
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF8B5CF6),
                            ),
                            MetricCard(
                              label: 'Rapor selesai',
                              value: compactNumber(data['completed_reports']),
                              icon: Icons.school_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                  ),
                  const SizedBox(height: 26),
                  const SectionHeading(title: 'Akses cepat'),
                  const SizedBox(height: 12),
                  _QuickActions(user: widget.user, onTap: widget.onOpenFeature),
                  const SizedBox(height: 28),
                  SectionHeading(
                    title: 'Agenda terdekat',
                    action: TextButton(
                      onPressed: () => widget.onOpenFeature('calendar'),
                      child: const Text('Lihat semua'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (events.isEmpty)
                    const _CompactEmpty(message: 'Belum ada agenda mendatang.')
                  else
                    ...events.take(3).map((event) => _EventTile(event: event)),
                  const SizedBox(height: 24),
                  SectionHeading(
                    title: 'Peringkat teratas',
                    action: TextButton(
                      onPressed: () => widget.onOpenFeature('leaderboard'),
                      child: const Text('Leaderboard'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (leaders.isEmpty)
                    const _CompactEmpty(message: 'Leaderboard belum tersedia.')
                  else
                    Card(
                      child: Column(
                        children: leaders
                            .take(3)
                            .map(
                              (row) => _LeaderRow(
                                row: row,
                                isLast: row == leaders.take(3).last,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.user,
    required this.today,
    required this.onTap,
  });

  final AppUser user;
  final Map<String, dynamic> today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkedIn = today['clock_in'] != null;
    final checkedOut = today['clock_out'] != null;
    final title = user.isIntern
        ? checkedOut
              ? 'Absensi hari ini lengkap'
              : checkedIn
              ? 'Jangan lupa Clock Out'
              : 'Siap memulai hari?'
        : 'Pantau internship dengan mudah';
    final description = user.isIntern
        ? checkedOut
              ? '${formatTime(today['clock_in'])} – ${formatTime(today['clock_out'])} WIB'
              : checkedIn
              ? 'Clock In ${formatTime(today['clock_in'])} WIB • ${today['work_mode'] ?? 'Office'}'
              : 'Catat kehadiran menggunakan Face ID dan lokasi.'
        : 'Progress, agenda, dan aktivitas penting tersedia dalam satu tempat.';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                Color(0xFF3E8B35),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D006838),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        user.roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFFE2F2E6),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              FeatureIconCluster(
                width: 92,
                height: 104,
                mainIcon: user.isIntern
                    ? Icons.fingerprint_rounded
                    : Icons.monitor_heart_outlined,
                supportingIcons: user.isIntern
                    ? const [Icons.location_on_outlined, Icons.schedule_rounded]
                    : const [
                        Icons.groups_2_outlined,
                        Icons.trending_up_rounded,
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user, required this.onTap});

  final AppUser user;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final actions = user.isIntern
        ? const [
            (
              'attendance',
              'Absensi',
              Icons.fingerprint_rounded,
              AppColors.primary,
            ),
            (
              'wfh',
              'Pengajuan WFH',
              Icons.home_work_outlined,
              Color(0xFF2563EB),
            ),
            ('evaluation', 'Rapor', Icons.school_outlined, Color(0xFFF59E0B)),
          ]
        : user.isMentor
        ? const [
            ('evaluation', 'Rapor', Icons.school_outlined, Color(0xFFF59E0B)),
            (
              'calendar',
              'Kalender',
              Icons.calendar_month_outlined,
              Color(0xFF2563EB),
            ),
            (
              'leaderboard',
              'Peringkat',
              Icons.emoji_events_outlined,
              AppColors.primary,
            ),
          ]
        : const [
            (
              'attendance',
              'Absensi',
              Icons.fact_check_outlined,
              AppColors.primary,
            ),
            ('wfh', 'Review WFH', Icons.home_work_outlined, Color(0xFF2563EB)),
            ('evaluation', 'Rapor', Icons.school_outlined, Color(0xFFF59E0B)),
          ];
    return SizedBox(
      height: 124,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item == actions.last ? 0 : 10,
                  ),
                  child: _QuickActionCard(
                    label: item.$2,
                    icon: item.$3,
                    color: item.$4,
                    onTap: () => onTap(item.$1),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: .12)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17221C),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.event_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['theme']?.toString() ?? 'Calendar Sharing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(formatShortDate(event['date'])),
              ],
            ),
          ),
          StatusPill(event['status']?.toString() ?? 'Open'),
        ],
      ),
    ),
  );
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.row, required this.isLast});
  final Map<String, dynamic> row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(row['intern']);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#${row['rank'] ?? '-'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  intern['name']?.toString() ?? 'Intern',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${row['score'] ?? 0} pts',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 52),
      ],
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(message, textAlign: TextAlign.center),
  );
}
