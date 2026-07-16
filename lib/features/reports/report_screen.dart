import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../widgets/common.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({required this.user, required this.repository, super.key});

  final AppUser user;
  final AppRepository repository;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>>? _evaluations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.dashboard(),
        widget.repository.evaluations(widget.user),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _evaluations = results[1] as List<Map<String, dynamic>>;
        _error = null;
      });
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  double _average(String key) {
    if (_evaluations?.isEmpty ?? true) return 0;
    return _evaluations!
            .map((item) => asDouble(item[key]))
            .reduce((a, b) => a + b) /
        _evaluations!.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_dashboard == null && _error == null) return const LoadingList();
    if (_dashboard == null) return ErrorState(message: _error!, onRetry: _load);
    final projectTypes = asMap(_dashboard!['project_type_counts']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Report',
            subtitle: 'Ringkasan operasional dari data internship terkini.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 38,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Snapshot program',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_dashboard!['period'] ?? '-'}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 290,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.25,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                MetricCard(
                  label: 'Intern aktif',
                  value: compactNumber(_dashboard!['total_interns']),
                  icon: Icons.groups_2_outlined,
                ),
                MetricCard(
                  label: 'Project aktif',
                  value: compactNumber(_dashboard!['active_projects']),
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF2563EB),
                ),
                MetricCard(
                  label: 'Progress rata-rata',
                  value:
                      '${asDouble(_dashboard!['average_progress']).toStringAsFixed(1)}%',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                MetricCard(
                  label: 'Rapor selesai',
                  value: '${_evaluations?.length ?? 0}',
                  icon: Icons.school_outlined,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeading(title: 'Rata-rata kompetensi'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _ReportBar(
                    label: 'Hard Skill',
                    value: _average('hard_skill'),
                  ),
                  _ReportBar(
                    label: 'Collaboration',
                    value: _average('collaboration'),
                  ),
                  _ReportBar(label: 'Ownership', value: _average('ownership')),
                  _ReportBar(
                    label: 'Sharing',
                    value: _average('sharing'),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Komposisi project'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: projectTypes.isEmpty
                  ? const Text('Belum ada data tipe project.')
                  : Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: projectTypes.entries
                          .map(
                            (entry) => Chip(
                              avatar: const Icon(
                                Icons.workspaces_outline,
                                size: 17,
                                color: AppColors.primary,
                              ),
                              label: Text('${entry.key}: ${entry.value}'),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Report mobile ini dirangkum dari endpoint dashboard dan evaluasi. Data selalu mengikuti source of truth API.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final double value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 18),
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
              value.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: (value / 100).clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: AppColors.mint,
        ),
      ],
    ),
  );
}
