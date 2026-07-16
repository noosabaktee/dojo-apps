import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.repository, super.key});

  final AppRepository repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.leaderboard();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null) return const LoadingList();
    if (_data == null) return ErrorState(message: _error!, onRetry: _load);
    final items = asMapList(_data!['items']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          const ScreenTitle(
            title: 'Leaderboard',
            subtitle: 'Apresiasi progress dan kontribusi intern.',
          ),
          const SizedBox(height: 22),
          if (items.isEmpty)
            const EmptyState(
              title: 'Belum ada peringkat',
              message:
                  'Leaderboard akan muncul setelah project mulai berjalan.',
              icon: Icons.emoji_events_outlined,
            )
          else ...[
            _Podium(items: items.take(3).toList()),
            const SizedBox(height: 22),
            Card(
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final intern = asMap(item['intern']);
                  final mentor = asMap(item['mentor']);
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: entry.key < 3
                              ? AppColors.primary
                              : AppColors.mint,
                          foregroundColor: entry.key < 3
                              ? Colors.white
                              : AppColors.primary,
                          child: Text(
                            '${item['rank'] ?? entry.key + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          intern['name']?.toString() ?? 'Intern',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          mentor['name']?.toString() ??
                              item['main_project']?.toString() ??
                              'Belum ada mentor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item['score'] ?? 0}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Text('poin', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      if (entry.key != items.length - 1)
                        const Divider(height: 1, indent: 78),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final reordered = <Map<String, dynamic>>[
      if (items.length > 1) items[1],
      items[0],
      if (items.length > 2) items[2],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: reordered.map((item) {
        final isFirst = item['rank'] == 1;
        final intern = asMap(item['intern']);
        final name = intern['name']?.toString() ?? 'Intern';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                if (isFirst)
                  const Icon(Icons.workspace_premium, color: Color(0xFFF5A623)),
                CircleAvatar(
                  radius: isFirst ? 30 : 25,
                  backgroundColor: isFirst ? AppColors.primary : AppColors.mint,
                  foregroundColor: isFirst ? Colors.white : AppColors.primary,
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: isFirst ? 22 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('${item['score'] ?? 0} poin'),
                const SizedBox(height: 10),
                Container(
                  height: isFirst ? 58 : 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFirst ? AppColors.primary : AppColors.mint,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    '#${item['rank']}',
                    style: TextStyle(
                      color: isFirst ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
