import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class WfhScreen extends StatefulWidget {
  const WfhScreen({required this.repository, super.key});

  final AppRepository repository;

  @override
  State<WfhScreen> createState() => _WfhScreenState();
}

class _WfhScreenState extends State<WfhScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  String _filter = 'Semua';
  int? _processingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.wfhRequests();
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

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'Semua') return _items ?? const [];
    return (_items ?? const [])
        .where((item) => item['status']?.toString() == _filter)
        .toList();
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    String? note;
    if (!approve) {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tolak pengajuan?'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Catatan penolakan',
              hintText:
                  'Jelaskan alasan agar intern dapat memperbaiki pengajuan.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Tolak'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Setujui WFH?'),
          content: Text(
            'Setujui pengajuan ${asMap(item['intern'])['name'] ?? 'intern'} untuk ${formatDate(item['start_date'])} sampai ${formatDate(item['end_date'])}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Setujui'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final id = asInt(item['id']);
    setState(() => _processingId = id);
    try {
      final message = await widget.repository.reviewWfh(
        id,
        approve: approve,
        note: note,
      );
      if (mounted) showMessage(context, message);
      await _load();
    } on ApiException catch (exception) {
      if (mounted) showMessage(context, exception.message);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null && _error == null) return const LoadingList();
    if (_items == null) return ErrorState(message: _error!, onRetry: _load);
    final pending = _items!.where((item) => item['status'] == 'Pending').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ScreenTitle(
            title: 'Pengajuan WFH',
            subtitle: '$pending pengajuan menunggu keputusan.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  ['Semua', 'Pending', 'Approved', 'Rejected', 'Cancelled']
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                            label: Text(filter),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            const EmptyState(
              title: 'Tidak ada pengajuan',
              message: 'Pengajuan dengan status ini belum tersedia.',
              icon: Icons.home_work_outlined,
            )
          else
            ..._filtered.map(
              (item) => _WfhCard(
                item: item,
                processing: _processingId == asInt(item['id']),
                onApprove: () => _review(item, true),
                onReject: () => _review(item, false),
              ),
            ),
        ],
      ),
    );
  }
}

class _WfhCard extends StatelessWidget {
  const _WfhCard({
    required this.item,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(item['intern']);
    final status = item['status']?.toString() ?? 'Pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.mint,
                  foregroundColor: AppColors.primary,
                  child: Text(
                    (intern['name']?.toString() ?? 'I')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intern['name']?.toString() ?? 'Intern',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${formatDate(item['start_date'])} – ${formatDate(item['end_date'])}',
                      ),
                    ],
                  ),
                ),
                StatusPill(status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item['reason']?.toString() ?? '-',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (item['attachment_available'] == true) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 5),
                  Text('Lampiran tersedia', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
            if (item['review_note'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Catatan: ${item['review_note']}'),
              ),
            ],
            if (status == 'Pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: processing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: processing ? null : onApprove,
                      child: processing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
