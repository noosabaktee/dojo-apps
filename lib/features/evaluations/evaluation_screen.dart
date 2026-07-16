import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({
    required this.user,
    required this.repository,
    super.key,
  });

  final AppUser user;
  final AppRepository repository;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.evaluations(widget.user);
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

  @override
  Widget build(BuildContext context) {
    if (_items == null && _error == null) return const LoadingList();
    if (_items == null) return ErrorState(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ScreenTitle(
            title: 'Rapor Intern',
            subtitle: widget.user.isIntern
                ? 'Lihat hasil evaluasi akhir internship kamu.'
                : 'Ringkasan kompetensi dan perkembangan intern.',
          ),
          const SizedBox(height: 22),
          if (_items!.isEmpty)
            const EmptyState(
              title: 'Rapor belum tersedia',
              message: 'Evaluasi yang sudah diselesaikan akan tampil di sini.',
              icon: Icons.school_outlined,
            )
          else
            ..._items!.map(
              (item) => _EvaluationCard(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EvaluationDetailScreen(item: item),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(item['intern']);
    final score = asDouble(item['exposure_score']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: (score / 100).clamp(0, 1),
                      strokeWidth: 6,
                      backgroundColor: AppColors.mint,
                    ),
                  ),
                  Text(
                    score.round().toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intern['name']?.toString() ?? 'Rapor Internship',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Selesai ${formatDate(item['completed_at'])}'),
                    const SizedBox(height: 7),
                    StatusPill(
                      item['certificate_published'] == true
                          ? 'Sertifikat terbit'
                          : 'Evaluasi selesai',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class EvaluationDetailScreen extends StatelessWidget {
  const EvaluationDetailScreen({required this.item, super.key});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(item['intern']);
    final evaluator = asMap(item['evaluator']);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Rapor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intern['name']?.toString() ?? 'Intern',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nilai akhir ${asDouble(item['exposure_score']).toStringAsFixed(1)} / 100',
                  style: const TextStyle(color: Color(0xFFDCEFE2)),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: (asDouble(item['exposure_score']) / 100).clamp(0, 1),
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Kompetensi'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _ScoreRow(
                    label: 'Hard Skill',
                    value: asDouble(item['hard_skill']),
                  ),
                  _ScoreRow(
                    label: 'Collaboration',
                    value: asDouble(item['collaboration']),
                  ),
                  _ScoreRow(
                    label: 'Ownership',
                    value: asDouble(item['ownership']),
                  ),
                  _ScoreRow(
                    label: 'Sharing',
                    value: asDouble(item['sharing']),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _NarrativeCard(
            title: 'Kekuatan',
            icon: Icons.auto_awesome_outlined,
            text: item['strength']?.toString(),
          ),
          _NarrativeCard(
            title: 'Area pengembangan',
            icon: Icons.trending_up_rounded,
            text: item['development']?.toString(),
          ),
          _NarrativeCard(
            title: 'Rekomendasi',
            icon: Icons.lightbulb_outline_rounded,
            text: item['recommendation']?.toString(),
          ),
          const SizedBox(height: 8),
          Text(
            'Dievaluasi oleh ${evaluator['name'] ?? '-'} • ${formatDate(item['completed_at'])}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final double value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 17),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: (value / 100).clamp(0, 1),
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: AppColors.mint,
        ),
      ],
    ),
  );
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.title, required this.icon, this.text});
  final String title;
  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(text?.isNotEmpty == true ? text! : 'Belum ada catatan.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
