import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

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
  final _picker = ImagePicker();
  Map<String, dynamic>? _data;
  Map<int, String> _internNames = const {};
  String? _error;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
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
        await widget.notifications.scheduleAttendanceReminders(
          asMap(data['settings']),
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _performAction(bool checkIn) async {
    setState(() => _processing = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 68,
        maxWidth: 1080,
        preferredCameraDevice: CameraDevice.front,
      );
      if (photo == null) return;
      final position = await _position();
      final result = await widget.repository.attendanceAction(
        checkIn: checkIn,
        imageBytes: await photo.readAsBytes(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      if (!mounted) return;
      showMessage(
        context,
        checkIn ? 'Clock In berhasil dicatat.' : 'Clock Out berhasil dicatat.',
      );
      setState(() {
        _data = {...?_data, 'today': result};
      });
      await _load();
    } on ApiException catch (exception) {
      if (mounted) showMessage(context, exception.message);
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
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
    if (proceed != true) return;
    setState(() => _processing = true);
    try {
      final images = <Uint8List>[];
      for (var index = 0; index < 3; index++) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 70,
          maxWidth: 1080,
        );
        if (image == null) throw Exception('Pendaftaran dibatalkan.');
        images.add(await image.readAsBytes());
        if (mounted && index < 2) {
          showMessage(
            context,
            'Foto ${index + 1}/3 tersimpan. Ambil foto berikutnya.',
          );
        }
      }
      await widget.repository.enrollFace(images);
      if (mounted) showMessage(context, 'Face ID berhasil didaftarkan.');
      await _load();
    } on ApiException catch (exception) {
      if (mounted) showMessage(context, exception.message);
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString().replaceFirst('Exception: ', ''));
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Absensi',
            subtitle: 'Face ID dan lokasi menjaga catatan tetap akurat.',
          ),
          const SizedBox(height: 22),
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
                  '${_data!['work_mode'] ?? today['work_mode'] ?? 'Office'} • ${formatDate(today['date'] ?? DateTime.now())}',
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
                    onPressed: _processing || !faceRegistered || checkedOut
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
                            checkedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      checkedOut
                          ? 'Selesai hari ini'
                          : checkedIn
                          ? 'Clock Out sekarang'
                          : 'Clock In sekarang',
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  checkedIn && !checkedOut
                      ? 'Clock Out mulai ${settings['clock_out_start'] ?? '--:--'} WIB'
                      : 'Clock In ${settings['clock_in_start'] ?? '--:--'} – ${settings['clock_in_end'] ?? '--:--'} WIB',
                  style: Theme.of(context).textTheme.bodySmall,
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
    final records = asMapList(_data!['records']);
    final present = records.where((item) => item['clock_in'] != null).length;
    final completed = records.where((item) => item['clock_out'] != null).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Monitoring Absensi',
            subtitle: 'Pantau kehadiran dan kelengkapan Clock Out intern.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 138,
            child: Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Clock In tercatat',
                    value: '$present',
                    icon: Icons.login_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Absensi lengkap',
                    value: '$completed',
                    icon: Icons.task_alt_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const SectionHeading(title: 'Catatan terbaru'),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const EmptyState(
              title: 'Belum ada absensi',
              message: 'Catatan kehadiran intern akan muncul di sini.',
            )
          else
            ...records.map(
              (record) => _AttendanceTile(
                record: record,
                name: _internNames[asInt(record['intern_id'])],
              ),
            ),
        ],
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

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record, this.name});
  final Map<String, dynamic> record;
  final String? name;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.schedule_rounded, color: AppColors.primary),
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
          StatusPill(record['status']?.toString() ?? 'Hadir'),
        ],
      ),
    ),
  );
}
