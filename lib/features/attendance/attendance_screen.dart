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
    final imageBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceCameraSheet(checkIn: checkIn),
    );
    if (imageBytes == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final position = await _position();
      final result = await widget.repository.attendanceAction(
        checkIn: checkIn,
        imageBytes: imageBytes,
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
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Absensi belum berhasil',
          message: exception.message,
        );
      }
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
    final records = asMapList(_data!['records']);
    final todayRecords = asMapList(_data!['today_records']);
    final summary = asMap(_data!['today_summary']);
    final total = asInt(summary['total']);
    final present = asInt(summary['clocked_in']);
    final completed = asInt(summary['completed']);
    final pending = asInt(summary['not_checked_in']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const ScreenTitle(
            title: 'Monitoring Absensi',
            subtitle: 'Rekap kehadiran seluruh intern dalam satu layar.',
          ),
          const SizedBox(height: 18),
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
              message: 'Tarik layar ke bawah untuk memuat ulang data hari ini.',
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
          if (records.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeading(title: 'Riwayat terbaru'),
            const SizedBox(height: 10),
            ...records
                .take(12)
                .map(
                  (record) => _AttendanceTile(
                    record: record,
                    name: _internNames[asInt(record['intern_id'])],
                  ),
                ),
          ],
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

class _AttendanceCameraSheet extends StatefulWidget {
  const _AttendanceCameraSheet({required this.checkIn});

  final bool checkIn;

  @override
  State<_AttendanceCameraSheet> createState() => _AttendanceCameraSheetState();
}

class _AttendanceCameraSheetState extends State<_AttendanceCameraSheet> {
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
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Front cameras may not expose flash controls.
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {});
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

  Future<void> _capture() async {
    final controller = _controller;
    if (_taking || controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() => _taking = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on CameraException {
      if (mounted) {
        setState(() {
          _taking = false;
          _error =
              'Foto gagal diambil. Pastikan kamera tidak digunakan aplikasi lain.';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              children: [
                const Text(
                  'Posisikan wajah di dalam bingkai dan pastikan pencahayaan cukup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFDCEFE2)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: ready && !_taking ? _capture : null,
                    icon: _taking
                        ? const SizedBox.square(
                            dimension: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      widget.checkIn
                          ? 'Ambil foto & Clock In'
                          : 'Ambil foto & Clock Out',
                    ),
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
