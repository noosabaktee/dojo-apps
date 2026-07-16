import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({required this.repository, super.key});

  final AppRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  List<Map<String, dynamic>>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final last = DateTime(_month.year, _month.month + 1, 0);
    try {
      final events = await widget.repository.calendarEvents(
        from: DateFormat('yyyy-MM-dd').format(_month),
        to: DateFormat('yyyy-MM-dd').format(last),
      );
      if (mounted) {
        setState(() {
          _events = events;
          _error = null;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = _month;
      _events = null;
    });
    _load();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> get _selectedEvents =>
      (_events ?? const []).where((event) {
        final date = parseDate(event['date']);
        return date != null && _sameDay(date, _selected);
      }).toList();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Calendar Sharing',
            subtitle: 'Temukan sesi berbagi dan agenda tim.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy', 'id_ID').format(_month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                        .map(
                          (day) => Expanded(
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    month: _month,
                    selected: _selected,
                    events: _events ?? const [],
                    onSelect: (date) => setState(() => _selected = date),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeading(title: formatDate(_selected)),
          const SizedBox(height: 10),
          if (_events == null && _error == null)
            const LoadingList()
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_selectedEvents.isEmpty)
            const EmptyState(
              title: 'Tidak ada agenda',
              message: 'Pilih tanggal bertanda untuk melihat agenda sharing.',
              icon: Icons.event_available_outlined,
            )
          else
            ..._selectedEvents.map((event) => _EventCard(event: event)),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<Map<String, dynamic>> events;
  final ValueChanged<DateTime> onSelect;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = month.weekday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final count = ((firstWeekday - 1 + days + 6) ~/ 7) * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: .9,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 2;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, day);
        final isSelected = _sameDay(date, selected);
        final isToday = _sameDay(date, DateTime.now());
        final hasEvent = events.any((event) {
          final eventDate = parseDate(event['date']);
          return eventDate != null && _sameDay(date, eventDate);
        });
        return InkWell(
          onTap: () => onSelect(date),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                      ? AppColors.mint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (hasEvent)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event['theme']?.toString() ?? 'Calendar Sharing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(event['status']?.toString() ?? 'Open'),
            ],
          ),
          if (event['objective'] != null) ...[
            const SizedBox(height: 14),
            Text(event['objective'].toString()),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 17,
                color: AppColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                '${formatShortDate(event['date'])}, ${formatTime(event['date'])} WIB',
              ),
            ],
          ),
          if (event['target_audience'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(event['target_audience'].toString())),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
