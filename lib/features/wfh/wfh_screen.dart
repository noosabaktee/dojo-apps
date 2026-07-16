import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';
import '../documents/document_viewer_screen.dart';

class WfhScreen extends StatefulWidget {
  const WfhScreen({required this.user, required this.repository, super.key});

  final AppUser user;
  final AppRepository repository;

  @override
  State<WfhScreen> createState() => _WfhScreenState();
}

class _WfhScreenState extends State<WfhScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  String _filter = 'Semua';
  int? _processingId;

  bool get _isAdmin => widget.user.isAdmin;

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

  Future<void> _createRequest() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _WfhRequestSheet(repository: widget.repository),
    );
    if (message == null || !mounted) return;
    showMessage(context, message);
    await _load();
  }

  Future<void> _review(Map<String, dynamic> item, bool approve) async {
    if (item['status']?.toString() != 'Pending') {
      await showAppAlert(
        context,
        title: 'Review sudah selesai',
        message:
            'Pengajuan yang sudah disetujui atau ditolak hanya dapat diubah melalui web Dojo.',
        icon: Icons.lock_outline_rounded,
        color: AppColors.primary,
      );
      return;
    }
    final controller = TextEditingController(
      text: item['review_note']?.toString() ?? '',
    );
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Setujui pengajuan WFH' : 'Tolak pengajuan WFH'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${asMap(item['intern'])['name'] ?? 'Intern'} • '
              '${formatDate(item['start_date'])} – ${formatDate(item['end_date'])}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                labelText: approve
                    ? 'Catatan peninjau (opsional)'
                    : 'Catatan penolakan',
                hintText: approve
                    ? 'Tambahkan arahan atau catatan untuk intern.'
                    : 'Jelaskan alasan penolakan atau pembatalan WFH.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: approve
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final value = controller.text.trim();
              if (!approve && value.isEmpty) {
                await showAppAlert(
                  context,
                  message: 'Catatan wajib diisi saat pengajuan ditolak.',
                );
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context, value);
            },
            child: Text(approve ? 'Simpan & setujui' : 'Simpan & tolak'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (note == null) return;

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
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Review belum tersimpan',
          message: exception.message,
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
          'Pengajuan yang dibatalkan tidak dapat digunakan untuk absensi WFH.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan pengajuan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = asInt(item['id']);
    setState(() => _processingId = id);
    try {
      final message = await widget.repository.cancelWfh(id);
      if (mounted) showMessage(context, message);
      await _load();
    } on ApiException catch (exception) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Pengajuan belum dibatalkan',
          message: exception.message,
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _openAttachment(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerScreen(
          title: 'Lampiran WFH',
          loader: () => widget.repository.wfhAttachment(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null && _error == null) return const LoadingList();
    if (_items == null) return ErrorState(message: _error!, onRetry: _load);
    final pending = _items!.where((item) => item['status'] == 'Pending').length;
    final approved = _items!
        .where((item) => item['status'] == 'Approved')
        .length;
    final rejected = _items!
        .where((item) => item['status'] == 'Rejected')
        .length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ScreenTitle(
            title: 'Pengajuan WFH',
            subtitle: _isAdmin
                ? '$pending pengajuan menunggu keputusan.'
                : 'Ajukan WFH sebelum absensi dari luar kantor.',
            action: _isAdmin
                ? null
                : IconButton.filled(
                    onPressed: _createRequest,
                    tooltip: 'Buat pengajuan',
                    icon: const Icon(Icons.add_rounded),
                  ),
          ),
          const SizedBox(height: 18),
          FeatureBanner(
            badge: _isAdmin ? 'Review HRD / Headmaster' : 'Pengajuan intern',
            title: _isAdmin
                ? '$pending pengajuan menunggu review'
                : 'Tetap produktif dari lokasi terbaikmu',
            subtitle: _isAdmin
                ? 'Periksa lampiran, rentang tanggal, lalu berikan catatan yang jelas.'
                : 'Ajukan WFH dengan alasan, tanggal, dan dokumen pendukung.',
            icon: Icons.home_work_rounded,
            supportingIcons: _isAdmin
                ? const [Icons.rate_review_outlined, Icons.task_alt_rounded]
                : const [
                    Icons.calendar_month_outlined,
                    Icons.attach_file_rounded,
                  ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatusCount(
                  label: 'Menunggu',
                  value: pending,
                  color: AppColors.warning,
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StatusCount(
                  label: 'Disetujui',
                  value: approved,
                  color: AppColors.primary,
                  icon: Icons.check_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StatusCount(
                  label: 'Ditolak',
                  value: rejected,
                  color: AppColors.danger,
                  icon: Icons.close_rounded,
                ),
              ),
            ],
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
                            label: Text(_filterLabel(filter)),
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
                isAdmin: _isAdmin,
                processing: _processingId == asInt(item['id']),
                onApprove: () => _review(item, true),
                onReject: () => _review(item, false),
                onCancel: () => _cancel(item),
                onAttachment: () => _openAttachment(item),
              ),
            ),
        ],
      ),
    );
  }

  String _filterLabel(String value) => switch (value) {
    'Pending' => 'Menunggu',
    'Approved' => 'Disetujui',
    'Rejected' => 'Ditolak',
    'Cancelled' => 'Dibatalkan',
    _ => value,
  };
}

class _WfhCard extends StatelessWidget {
  const _WfhCard({
    required this.item,
    required this.isAdmin,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onAttachment,
  });

  final Map<String, dynamic> item;
  final bool isAdmin;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onAttachment;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(item['intern']);
    final status = item['status']?.toString() ?? 'Pending';
    final internName = intern['name']?.toString() ?? 'Intern';
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
                    (isAdmin ? internName : 'WFH')
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
                        isAdmin ? internName : 'Work From Home',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${formatDate(item['start_date'])} – ${formatDate(item['end_date'])}',
                      ),
                    ],
                  ),
                ),
                StatusPill(_statusLabel(status)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item['reason']?.toString() ?? '-',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (item['attachment_available'] == true) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onAttachment,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Lihat lampiran'),
              ),
            ],
            if (item['review_note']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Catatan peninjau: ${item['review_note']}'),
                    ),
                  ],
                ),
              ),
            ],
            if (isAdmin && status == 'Pending') ...[
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
            ] else if (isAdmin &&
                (status == 'Approved' || status == 'Rejected')) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .12),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Keputusan sudah dikunci. Perubahan berikutnya hanya dapat dilakukan melalui web Internship Monitoring.',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!isAdmin && status == 'Pending') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: processing ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Batalkan pengajuan'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
    'Approved' => 'Disetujui',
    'Rejected' => 'Ditolak',
    'Cancelled' => 'Dibatalkan',
    _ => 'Menunggu',
  };
}

class _WfhRequestSheet extends StatefulWidget {
  const _WfhRequestSheet({required this.repository});

  final AppRepository repository;

  @override
  State<_WfhRequestSheet> createState() => _WfhRequestSheetState();
}

class _WfhRequestSheetState extends State<_WfhRequestSheet> {
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  XFile? _attachment;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final today = DateUtils.dateOnly(jakartaNow());
    final selected = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? today)
          : (_endDate ?? _startDate ?? today),
      firstDate: start ? today : (_startDate ?? today),
      lastDate: DateTime(today.year + 2),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = selected;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Dokumen pendukung',
            extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: [
              'application/pdf',
              'image/jpeg',
              'image/png',
              'image/webp',
            ],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        if (mounted) {
          await showAppAlert(
            context,
            message: 'Ukuran lampiran maksimal 5 MB.',
          );
        }
        return;
      }
      if (mounted) setState(() => _attachment = file);
    } catch (_) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Lampiran tidak dapat dibuka',
          message:
              'Pilih ulang file PDF atau gambar dari penyimpanan perangkat.',
        );
      }
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final errors = <String>[];
    if (_startDate == null || _endDate == null) {
      errors.add('Pilih tanggal mulai dan selesai WFH.');
    } else if (_endDate!.isBefore(_startDate!)) {
      errors.add('Tanggal selesai tidak boleh sebelum tanggal mulai.');
    }
    if (_reasonController.text.trim().isEmpty) {
      errors.add('Alasan dan rencana kerja wajib diisi.');
    }
    if (_attachment == null) {
      errors.add('Lampiran pendukung wajib dipilih.');
    }
    if (errors.isNotEmpty) {
      await showAppAlert(context, message: errors.join('\n\n'));
      return;
    }

    setState(() => _submitting = true);
    var submitted = false;
    try {
      final message = await widget.repository.submitWfh(
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text,
        attachment: _attachment!,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(Duration.zero);
      submitted = true;
      if (mounted) Navigator.of(context).pop(message);
    } on ApiException catch (exception) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Pengajuan belum terkirim',
          message: exception.message,
        );
      }
    } catch (_) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Pengajuan belum terkirim',
          message: 'Lampiran atau koneksi bermasalah. Coba pilih ulang file.',
        );
      }
    } finally {
      if (mounted && !submitted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buat pengajuan WFH',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            const Text(
              'WFH bukan pengajuan cuti. Absensi tetap menggunakan Face ID dan lokasi.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Mulai WFH',
                    value: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'Selesai WFH',
                    value: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              minLines: 4,
              maxLines: 6,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'Alasan dan rencana kerja',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: Icon(
                _attachment == null
                    ? Icons.attach_file_rounded
                    : Icons.check_circle_rounded,
              ),
              label: Text(_attachment?.name ?? 'Pilih lampiran (maks. 5 MB)'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Kirim ke HRD / Headmaster'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(value == null ? 'Pilih' : formatDate(value)),
    ),
  );
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
