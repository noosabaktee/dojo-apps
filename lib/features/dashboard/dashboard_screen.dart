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
                              firstName(widget.user.name),
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
                      widget.user.isIntern ? 'attendance' : 'report',
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionHeading(title: 'Ringkasan hari ini'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.45,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: widget.user.isIntern
                          ? [
                              MetricCard(
                                label: 'Progress rata-rata',
                                value:
                                    '${asDouble(data['average_progress']).round()}%',
                                icon: Icons.trending_up_rounded,
                              ),
                              MetricCard(
                                label: 'Project aktif',
                                value: compactNumber(data['active_projects']),
                                icon: Icons.work_outline_rounded,
                                color: const Color(0xFF2563EB),
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
                            ],
                    ),
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
        : 'Progress, agenda, dan laporan penting tersedia dalam satu tempat.';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064928), AppColors.primary, Color(0xFF4F982B)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33006838),
              blurRadius: 24,
              offset: Offset(0, 12),
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
                      color: Color(0xFFDCEFE2),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                user.isIntern
                    ? Icons.fingerprint_rounded
                    : Icons.insights_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
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
            ('attendance', 'Absensi', Icons.fingerprint_rounded),
            ('calendar', 'Kalender', Icons.calendar_month_outlined),
            ('evaluation', 'Rapor', Icons.school_outlined),
          ]
        : user.isMentor
        ? const [
            ('evaluation', 'Rapor', Icons.school_outlined),
            ('calendar', 'Kalender', Icons.calendar_month_outlined),
            ('report', 'Report', Icons.analytics_outlined),
          ]
        : const [
            ('attendance', 'Absensi', Icons.fact_check_outlined),
            ('wfh', 'Review WFH', Icons.home_work_outlined),
            ('report', 'Report', Icons.analytics_outlined),
          ];
    return Row(
      children: actions
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: item == actions.last ? 0 : 10),
                child: InkWell(
                  onTap: () => onTap(item.$1),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(item.$3, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
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
