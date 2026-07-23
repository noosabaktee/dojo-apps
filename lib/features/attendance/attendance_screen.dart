import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/app_user.dart';
import '../../repositories/app_repository.dart';
import '../../services/local_notification_service.dart';
import '../../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    required this.user,
    required this.repository,
    required this.notifications,
    super.key,
  });

  final AppUser user;
  final AppRepository repository;
  final LocalNotificationService notifications;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, dynamic>? _data;
  Map<int, String> _internNames = const {};
  String? _error;
  bool _processing = false;
  int _adminTab = 0;
  DateTimeRange? _attendanceRange;
  List<Map<String, dynamic>>? _internGroups;
  String? _filteredError;
  bool _loadingFiltered = false;
  Timer? _clockOutAvailabilityTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clockOutAvailabilityTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.attendance(),
        if (widget.user.isAdmin) widget.repository.interns(),
      ]);
      final data = results.first as Map<String, dynamic>;
      final names = <int, String>{};
      if (widget.user.isAdmin && results.length > 1) {
        for (final intern in results[1] as List<Map<String, dynamic>>) {
          names[asInt(intern['id'])] = intern['name']?.toString() ?? 'Intern';
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _internNames = names;
        _error = null;
      });
      if (widget.user.isIntern) {
        _scheduleClockOutAvailability(asMap(data['settings']));
        try {
          await widget.notifications.scheduleAttendanceReminders(
            asMap(data['settings']),
          );
        } catch (_) {
          // Reminder perangkat tidak boleh mengubah absensi yang sudah berhasil.
        }
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  ({int hour, int minute})? _attendanceTime(dynamic value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  bool _clockOutHasStarted(dynamic value) {
    final time = _attendanceTime(value);
    if (time == null) return false;
    final now = jakartaNow();
    return now.hour > time.hour ||
        (now.hour == time.hour && now.minute >= time.minute);
  }

  void _scheduleClockOutAvailability(Map<String, dynamic> settings) {
    _clockOutAvailabilityTimer?.cancel();
    final time = _attendanceTime(settings['clock_out_start']);
    if (time == null) return;
    final now = jakartaNow();
    final secondsUntilStart =
        time.hour * 3600 +
        time.minute * 60 -
        (now.hour * 3600 + now.minute * 60 + now.second);
    if (secondsUntilStart <= 0) return;
    _clockOutAvailabilityTimer = Timer(
      Duration(seconds: secondsUntilStart + 1),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _performAction(bool checkIn) async {
    setState(() => _processing = true);
    try {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        enableDrag: false,
        isDismissible: false,
        builder: (_) => _AttendanceCameraSheet(
          checkIn: checkIn,
          onVerify: (imageBytes) async {
            final position = await _position();
            return widget.repository.attendanceAction(
              checkIn: checkIn,
              imageBytes: imageBytes,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
            );
          },
        ),
      );
      if (result == null || !mounted) return;
      showMessage(
        context,
        checkIn ? 'Clock In berhasil dicatat.' : 'Clock Out berhasil dicatat.',
      );
      setState(() {
        _data = {...?_data, 'today': result};
      });
      await _load();
    } catch (error) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Absensi belum berhasil',
          message: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pickAttendanceRange() async {
    final now = jakartaNow();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange:
          _attendanceRange ??
          DateTimeRange(
            start: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 29)),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: 'Pilih periode absensi',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
      saveText: 'Terapkan',
      fieldStartHintText: 'Dari tanggal',
      fieldEndHintText: 'Sampai tanggal',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _attendanceRange = selected;
      _internGroups = null;
    });
    await _loadFiltered();
  }

  Future<void> _loadFiltered() async {
    final range = _attendanceRange;
    if (range == null) return;
    setState(() {
      _loadingFiltered = true;
      _filteredError = null;
    });
    try {
      final groups = await widget.repository.attendanceInternGroups(
        from: range.start,
        to: range.end,
      );
      if (!mounted) return;
      setState(() => _internGroups = groups);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _filteredError = exception.message);
    } finally {
      if (mounted) setState(() => _loadingFiltered = false);
    }
  }

  Future<void> _refreshAdmin() async {
    await _load();
    if (_adminTab == 1 && _attendanceRange != null) {
      await _loadFiltered();
    }
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Aktifkan layanan lokasi untuk melakukan absensi.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi diperlukan untuk validasi absensi.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _enrollFace() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daftarkan Face ID'),
        content: const Text(
          'Ambil 3 foto wajah dari sudut sedikit berbeda. Pastikan pencahayaan terang dan hanya satu wajah terlihat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final images = await showDialog<List<Uint8List>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const _FaceEnrollmentDialog(),
    );
    if (!mounted || images == null || images.length < 3) return;
    setState(() => _processing = true);
    try {
      await widget.repository.enrollFace(images);
      if (mounted) showMessage(context, 'Face ID berhasil didaftarkan.');
      await _load();
    } on ApiException catch (exception) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Face ID belum tersimpan',
          message: exception.message,
        );
      }
    } catch (error) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Face ID belum tersimpan',
          message: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null) return const LoadingList();
    if (_data == null) return ErrorState(message: _error!, onRetry: _load);
    return widget.user.isIntern ? _internView() : _adminView();
  }

  Widget _internView() {
    final today = asMap(_data!['today']);
    final settings = asMap(_data!['settings']);
    final records = asMapList(_data!['records']);
    final faceRegistered = _data!['face_registered'] == true;
    final checkedIn = today['clock_in'] != null;
    final checkedOut = today['clock_out'] != null;
    final clockOutStarted = _clockOutHasStarted(settings['clock_out_start']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Absensi',
            subtitle: 'Kehadiran akurat dengan Face ID dan lokasi.',
          ),
          const SizedBox(height: 18),
          FeatureBanner(
            badge: '${formatShortDate(jakartaNow())} • WIB',
            title: checkedOut
                ? 'Kehadiran hari ini lengkap'
                : checkedIn
                ? 'Semangat menyelesaikan harimu'
                : 'Siap memulai hari?',
            subtitle: checkedOut
                ? 'Clock In dan Clock Out sudah tercatat dengan aman.'
                : 'Kamera hanya menyala saat tombol absensi ditekan.',
            icon: Icons.fingerprint_rounded,
            supportingIcons: const [
              Icons.videocam_outlined,
              Icons.location_on_outlined,
            ],
          ),
          const SizedBox(height: 18),
          if (!faceRegistered) ...[
            _FaceWarning(onEnroll: _processing ? null : _enrollFace),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    checkedOut
                        ? Icons.task_alt_rounded
                        : checkedIn
                        ? Icons.timer_outlined
                        : Icons.fingerprint_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  checkedOut
                      ? 'Kehadiran lengkap'
                      : checkedIn
                      ? 'Sedang bekerja'
                      : 'Belum Clock In',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  '${_data!['work_mode'] ?? today['work_mode'] ?? 'Office'} • ${formatDate(today['date'] ?? jakartaNow())}',
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _TimeBox(
                        label: 'Clock In',
                        time: formatTime(today['clock_in']),
                        status: today['clock_in_status']?.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeBox(
                        label: 'Clock Out',
                        time: formatTime(today['clock_out']),
                        status: today['clock_out_status']?.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _processing ||
                            !faceRegistered ||
                            checkedOut ||
                            (checkedIn && !clockOutStarted)
                        ? null
                        : () => _performAction(!checkedIn),
                    icon: _processing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            checkedIn && !clockOutStarted
                                ? Icons.lock_clock_outlined
                                : checkedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      checkedOut
                          ? 'Selesai hari ini'
                          : checkedIn && !clockOutStarted
                          ? 'Clock Out mulai ${settings['clock_out_start'] ?? '--:--'} WIB'
                          : checkedIn
                          ? 'Clock Out sekarang'
                          : 'Clock In sekarang',
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        checkedIn && !checkedOut
                            ? 'Clock Out mulai ${settings['clock_out_start'] ?? '--:--'} WIB'
                            : 'Clock In ${settings['clock_in_start'] ?? '--:--'} – ${settings['clock_in_end'] ?? '--:--'} WIB',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeading(title: 'Riwayat terbaru'),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const EmptyState(
              title: 'Belum ada riwayat',
              message: 'Catatan absensi akan muncul di sini.',
            )
          else
            ...records.map((record) => _AttendanceTile(record: record)),
        ],
      ),
    );
  }

  Widget _adminView() {
    final todayRecords = asMapList(_data!['today_records']);
    final summary = asMap(_data!['today_summary']);
    final total = asInt(summary['total']);
    final present = asInt(summary['clocked_in']);
    final completed = asInt(summary['completed']);
    final pending = asInt(summary['not_checked_in']);
    return RefreshIndicator(
      onRefresh: _refreshAdmin,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Monitoring Absensi',
            subtitle: 'Pantau absensi hari ini atau pilih periode riwayat.',
          ),
          const SizedBox(height: 18),
          DefaultTabController(
            length: 2,
            initialIndex: _adminTab,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                onTap: (index) => setState(() => _adminTab = index),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Absensi Hari Ini'),
                  Tab(text: 'Semua Absensi'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_adminTab == 0) ...[
            FeatureBanner(
              badge: '${formatShortDate(jakartaNow())} • WIB',
              title: '$present dari $total intern sudah hadir',
              subtitle: pending == 0
                  ? 'Seluruh intern sudah melakukan Clock In hari ini.'
                  : '$pending intern masih belum melakukan Clock In.',
              icon: Icons.groups_2_rounded,
              supportingIcons: const [
                Icons.fact_check_outlined,
                Icons.location_on_outlined,
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.48,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                MetricCard(
                  label: 'Total intern',
                  value: '$total',
                  icon: Icons.groups_2_outlined,
                ),
                MetricCard(
                  label: 'Sudah Clock In',
                  value: '$present',
                  icon: Icons.login_rounded,
                  color: const Color(0xFF2563EB),
                ),
                MetricCard(
                  label: 'Absensi lengkap',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
                MetricCard(
                  label: 'Belum Clock In',
                  value: '$pending',
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 25),
            const SectionHeading(title: 'Rekap seluruh intern hari ini'),
            const SizedBox(height: 10),
            if (todayRecords.isEmpty)
              const EmptyState(
                title: 'Rekap belum tersedia',
                message:
                    'Tarik layar ke bawah untuk memuat ulang data hari ini.',
              )
            else
              ...todayRecords.map(
                (record) => _AttendanceTile(
                  record: record,
                  name:
                      asMap(record['intern'])['name']?.toString() ??
                      _internNames[asInt(record['intern_id'])],
                ),
              ),
          ] else ...[
            _AttendanceRangeFilter(
              range: _attendanceRange,
              loading: _loadingFiltered,
              onTap: _loadingFiltered ? null : _pickAttendanceRange,
            ),
            const SizedBox(height: 18),
            if (_attendanceRange == null)
              const EmptyState(
                title: 'Pilih periode terlebih dahulu',
                message:
                    'Tentukan tanggal mulai dan selesai untuk menampilkan semua absensi.',
                icon: Icons.date_range_rounded,
              )
            else if (_loadingFiltered && _internGroups == null)
              const LoadingList()
            else if (_filteredError != null)
              ErrorState(message: _filteredError!, onRetry: _loadFiltered)
            else if (_internGroups?.isEmpty != false)
              const EmptyState(
                title: 'Tidak ada absensi',
                message: 'Tidak ada intern pada periode yang dipilih.',
                icon: Icons.event_busy_outlined,
              )
            else ...[
              SectionHeading(title: '${_internGroups!.length} intern'),
              const SizedBox(height: 10),
              ..._internGroups!.map(
                (group) => _InternAttendanceCard(
                  group: group,
                  range: _attendanceRange!,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttendanceRangeFilter extends StatelessWidget {
  const _AttendanceRangeFilter({
    required this.range,
    required this.loading,
    required this.onTap,
  });

  final DateTimeRange? range;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: AppColors.primary),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Filter periode wajib diisi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    range == null
                        ? 'Dari tanggal — Sampai tanggal'
                        : '${formatShortDate(range!.start)} — ${formatShortDate(range!.end)}',
                    style: TextStyle(
                      color: range == null ? AppColors.muted : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.tune_rounded),
              label: Text(
                loading
                    ? 'Memuat absensi...'
                    : range == null
                    ? 'Pilih tanggal'
                    : 'Ubah periode',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InternAttendanceCard extends StatelessWidget {
  const _InternAttendanceCard({required this.group, required this.range});

  final Map<String, dynamic> group;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(group['intern']);
    final summary = asMap(group['summary']);
    final records = asMapList(group['records']);
    final name = intern['name']?.toString().trim();
    final displayName = name?.isNotEmpty == true ? name! : 'Intern';
    final number = intern['number']?.toString().trim();
    final initial = displayName.substring(0, 1).toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: records.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _InternAttendanceDetailScreen(group: group, range: range),
                ),
              ),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (number?.isNotEmpty == true) number!,
                            '${asInt(summary['total'])} hari kerja',
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 13),
              _AttendanceSummaryCounts(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceSummaryCounts extends StatelessWidget {
  const _AttendanceSummaryCounts({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      _AttendanceStatusCount(
        label: 'Hadir',
        count: asInt(summary['present']),
        color: AppColors.primary,
      ),
      _AttendanceStatusCount(
        label: 'Terlambat',
        count: asInt(summary['late']),
        color: AppColors.warning,
      ),
      _AttendanceStatusCount(
        label: 'Tidak masuk',
        count: asInt(summary['absent']),
        color: AppColors.danger,
      ),
      if (asInt(summary['pending']) > 0)
        _AttendanceStatusCount(
          label: 'Belum absen',
          count: asInt(summary['pending']),
          color: const Color(0xFF2563EB),
        ),
    ],
  );
}

class _AttendanceStatusCount extends StatelessWidget {
  const _AttendanceStatusCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _InternAttendanceDetailScreen extends StatelessWidget {
  const _InternAttendanceDetailScreen({
    required this.group,
    required this.range,
  });

  final Map<String, dynamic> group;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final intern = asMap(group['intern']);
    final summary = asMap(group['summary']);
    final records = asMapList(group['records']);
    final name = intern['name']?.toString() ?? 'Intern';
    final number = intern['number']?.toString();
    final period = '${formatDate(range.start)} — ${formatDate(range.end)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Absensi')),
      body: AppPageBackground(
        variant: 1,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FeatureBanner(
              badge: number?.isNotEmpty == true ? number : 'Intern',
              title: name,
              subtitle: period,
              icon: Icons.person_rounded,
              supportingIcons: const [
                Icons.fact_check_outlined,
                Icons.date_range_rounded,
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _AttendanceSummaryCounts(summary: summary),
              ),
            ),
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Riwayat harian',
              action: Text(
                '${asInt(summary['total'])} hari',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              const EmptyState(
                title: 'Absensi belum tersedia',
                message: 'Belum ada detail absensi dalam periode ini.',
              )
            else
              ...records.map((record) => _AttendanceTile(record: record)),
          ],
        ),
      ),
    );
  }
}

class _FaceWarning extends StatelessWidget {
  const _FaceWarning({required this.onEnroll});
  final VoidCallback? onEnroll;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFAD58B)),
    ),
    child: Row(
      children: [
        const Icon(Icons.face_retouching_natural, color: AppColors.warning),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Face ID belum terdaftar. Daftarkan sebelum melakukan absensi.',
          ),
        ),
        TextButton(onPressed: onEnroll, child: const Text('Daftar')),
      ],
    ),
  );
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time, this.status});
  final String label;
  final String time;
  final String? status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(time, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          status ?? 'Belum tercatat',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: status == null ? AppColors.muted : AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _AttendanceCameraSheet extends StatefulWidget {
  const _AttendanceCameraSheet({required this.checkIn, required this.onVerify});

  final bool checkIn;
  final Future<Map<String, dynamic>> Function(Uint8List imageBytes) onVerify;

  @override
  State<_AttendanceCameraSheet> createState() => _AttendanceCameraSheetState();
}

class _AttendanceCameraSheetState extends State<_AttendanceCameraSheet> {
  CameraController? _controller;
  String? _error;
  bool _taking = false;
  Timer? _countdownTimer;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _countdownTimer?.cancel();
    _controller = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Kamera tidak ditemukan.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Front cameras may not expose flash controls.
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _countdown = 3);
      _startCountdown();
    } on CameraException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.code == 'CameraAccessDenied'
            ? 'Izin kamera diperlukan untuk verifikasi Face ID.'
            : 'Kamera tidak dapat dibuka. Periksa izin kamera.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        _captureAndVerify();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _captureAndVerify() async {
    final controller = _controller;
    if (_taking || controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() => _taking = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      final result = await widget.onVerify(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on CameraException {
      if (mounted) {
        setState(() {
          _taking = false;
          _error =
              'Live camera terhenti. Pastikan kamera tidak digunakan aplikasi lain.';
        });
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() {
          _taking = false;
          _error = exception.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _taking = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Container(
      height: MediaQuery.sizeOf(context).height * .82,
      decoration: const BoxDecoration(
        color: Color(0xFF101713),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5EE58C).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Color(0xFF5EE58C),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.checkIn
                            ? 'Verifikasi Clock In'
                            : 'Verifikasi Clock Out',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const Text(
                        'Kamera aktif hanya selama proses ini.',
                        style: TextStyle(
                          color: Color(0xFFAEC3B4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _taking ? null : () => Navigator.of(context).pop(),
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                if (_error != null)
                  _CameraError(message: _error!, onRetry: _initialize)
                else if (!ready)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  _CameraPreviewSurface(controller: controller!),
                if (_error == null) ...[
                  const Center(child: _FaceOval()),
                  const Positioned(top: 16, left: 16, child: _LiveBadge()),
                  if (ready && !_taking && _countdown > 0)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: _CountdownBadge(value: _countdown),
                    ),
                ],
                if (_taking)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          ColoredBox(
            color: const Color(0xFF101713),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                children: [
                  Text(
                    _taking
                        ? 'Memverifikasi Face ID dan lokasi dari live camera...'
                        : 'Posisikan wajah di dalam bingkai. Verifikasi berjalan otomatis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFDCEFE2)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _taking
                        ? 'Jangan tutup aplikasi selama proses berlangsung.'
                        : 'Tidak ada foto yang disimpan ke galeri.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFAEC3B4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    height: 62,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xCC101713),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF5EE58C), width: 2),
    ),
    child: Text(
      '$value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xCC101713),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: Color(0xFF5EE58C)),
        SizedBox(width: 6),
        Text(
          'LIVE CAMERA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    ),
  );
}

class _CameraPreviewSurface extends StatelessWidget {
  const _CameraPreviewSurface({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _FaceOval extends StatelessWidget {
  const _FaceOval();

  @override
  Widget build(BuildContext context) => Container(
    width: 174,
    height: 224,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white, width: 2.4),
      borderRadius: const BorderRadius.all(Radius.elliptical(87, 112)),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class _FaceEnrollmentDialog extends StatefulWidget {
  const _FaceEnrollmentDialog();

  @override
  State<_FaceEnrollmentDialog> createState() => _FaceEnrollmentDialogState();
}

class _FaceEnrollmentDialogState extends State<_FaceEnrollmentDialog> {
  final List<Uint8List> _samples = [];
  CameraController? _controller;
  String? _error;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Kamera tidak ditemukan.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } on CameraException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.code == 'CameraAccessDenied'
            ? 'Izin kamera diperlukan untuk mendaftarkan Face ID.'
            : 'Kamera tidak dapat dibuka. Periksa izin kamera.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_taking || controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() => _taking = true);
    try {
      final image = await controller.takePicture();
      _samples.add(await image.readAsBytes());
      if (!mounted) return;
      if (_samples.length >= 3) {
        Navigator.pop(context, _samples);
      } else {
        setState(() => _taking = false);
      }
    } on CameraException {
      if (mounted) {
        setState(() {
          _taking = false;
          _error = 'Foto gagal diambil. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Daftarkan Face ID',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _taking ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 390,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_error != null)
                  _CameraError(message: _error!, onRetry: _initialize)
                else if (!ready)
                  const ColoredBox(
                    color: Color(0xFF101713),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  _CameraPreviewSurface(controller: controller!),
                if (_error == null) ...[
                  const Center(child: _FaceOval()),
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: StatusPill('Foto ${_samples.length + 1} dari 3'),
                    ),
                  ),
                ],
                if (_taking)
                  const ColoredBox(
                    color: Color(0x44000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  _samples.isEmpty
                      ? 'Tatap lurus ke kamera.'
                      : _samples.length == 1
                      ? 'Miringkan wajah sedikit ke kiri.'
                      : 'Miringkan wajah sedikit ke kanan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: ready && !_taking ? _capture : null,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text('Ambil foto ${_samples.length + 1}/3'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record, this.name});
  final Map<String, dynamic> record;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final status = record['status']?.toString() ?? 'Hadir';
    final missing = record['clock_in'] == null;
    final completed = record['clock_out'] != null;
    final color = missing
        ? (status.contains('Tidak') ? AppColors.danger : AppColors.warning)
        : AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => _AttendanceDetailSheet(record: record, name: name),
        ),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  completed
                      ? Icons.task_alt_rounded
                      : missing
                      ? Icons.schedule_rounded
                      : Icons.login_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? formatDate(record['date']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name == null
                          ? '${formatTime(record['clock_in'])} – ${formatTime(record['clock_out'])} WIB'
                          : '${formatDate(record['date'])} • ${formatTime(record['clock_in'])} – ${formatTime(record['clock_out'])}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  StatusPill(status),
                  const SizedBox(height: 5),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 17,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceDetailSheet extends StatelessWidget {
  const _AttendanceDetailSheet({required this.record, this.name});

  final Map<String, dynamic> record;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final locationIn = asMap(record['location']);
    final locationOut = asMap(record['clock_out_location']);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name ?? 'Detail Absensi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDate(record['date'])} • ${record['work_mode'] ?? 'Office'}',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'Clock In',
                  time: formatTime(record['clock_in']),
                  status: record['clock_in_status']?.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(
                  label: 'Clock Out',
                  time: formatTime(record['clock_out']),
                  status: record['clock_out_status']?.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeading(title: 'Lokasi perangkat'),
          const SizedBox(height: 10),
          _LocationDetail(label: 'Clock In', location: locationIn),
          const SizedBox(height: 10),
          _LocationDetail(label: 'Clock Out', location: locationOut),
          if (record['note']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 20),
            const SectionHeading(title: 'Catatan'),
            const SizedBox(height: 8),
            Text(record['note'].toString()),
          ],
        ],
      ),
    );
  }
}

class _LocationDetail extends StatelessWidget {
  const _LocationDetail({required this.label, required this.location});

  final String label;
  final Map<String, dynamic> location;

  @override
  Widget build(BuildContext context) {
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    final hasCoordinates = latitude != null && longitude != null;
    final address = location['name']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  address?.isNotEmpty == true
                      ? address!
                      : hasCoordinates
                      ? '$latitude, $longitude'
                      : 'Belum tercatat',
                ),
                if (location['accuracy'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Akurasi ${asDouble(location['accuracy']).toStringAsFixed(0)} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (hasCoordinates || location['url'] != null)
            IconButton.filledTonal(
              onPressed: () => _openMap(location),
              tooltip: 'Buka peta',
              icon: const Icon(Icons.map_outlined, size: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _openMap(Map<String, dynamic> location) async {
    final rawUrl = location['url']?.toString();
    final uri = rawUrl?.isNotEmpty == true
        ? Uri.tryParse(rawUrl!)
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query='
            '${location['latitude']},${location['longitude']}',
          );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
