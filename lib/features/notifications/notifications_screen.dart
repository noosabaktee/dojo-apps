import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.repository, super.key});

  final AppRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.notifications();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    try {
      await widget.repository.markNotificationRead(asInt(item['id']));
      if (!mounted) return;
      setState(() => item['is_read'] = true);
    } on ApiException catch (exception) {
      if (mounted) showMessage(context, exception.message);
    }
  }

  Future<void> _readAll() async {
    try {
      await widget.repository.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final item in _items ?? const <Map<String, dynamic>>[]) {
          item['is_read'] = true;
        }
      });
      showMessage(context, 'Semua notifikasi sudah dibaca.');
    } on ApiException catch (exception) {
      if (mounted) showMessage(context, exception.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (_items?.any((item) => item['is_read'] != true) == true)
            TextButton(onPressed: _readAll, child: const Text('Baca semua')),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items == null && _error == null) return const LoadingList();
    if (_items == null) return ErrorState(message: _error!, onRetry: _load);
    if (_items!.isEmpty) {
      return const EmptyState(
        title: 'Belum ada notifikasi',
        message: 'Update kegiatan dan pengajuan akan muncul di sini.',
        icon: Icons.notifications_none_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items![index];
          final unread = item['is_read'] != true;
          return Card(
            color: unread ? const Color(0xFFF1F8EF) : Colors.white,
            child: InkWell(
              onTap: () => _read(item),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: unread ? AppColors.primary : AppColors.mint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _notificationIcon(item['type']?.toString()),
                        color: unread ? Colors.white : AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['title']?.toString() ?? 'Update Dojo',
                                  style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(item['message']?.toString() ?? ''),
                          const SizedBox(height: 7),
                          Text(
                            '${formatShortDate(item['created_at'])}, ${formatTime(item['created_at'])}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _notificationIcon(String? type) => switch (type) {
    'wfh' => Icons.home_work_outlined,
    'certificate' => Icons.workspace_premium_outlined,
    'internship' => Icons.school_outlined,
    _ => Icons.notifications_active_outlined,
  };
}
