import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/local_notification_service.dart';
import '../../state/app_session.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.session,
    required this.notifications,
    super.key,
  });

  final AppUser user;
  final AppSession session;
  final LocalNotificationService notifications;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late AppUser _user;
  bool _askingPermission = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) _user = widget.user;
  }

  Future<void> _enableNotifications() async {
    setState(() => _askingPermission = true);
    final granted = await widget.notifications.requestPermission();
    if (!mounted) return;
    setState(() => _askingPermission = false);
    showMessage(
      context,
      granted
          ? 'Notifikasi perangkat sudah diaktifkan.'
          : 'Izin notifikasi belum diberikan. Buka pengaturan perangkat bila sebelumnya ditolak.',
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Dojo?'),
        content: const Text(
          'Kamu perlu memasukkan email dan password lagi untuk masuk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await widget.session.logout();
    }
  }

  Future<void> _changePhoto() async {
    try {
      final photo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Foto profil',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          ),
        ],
      );
      if (photo == null || !mounted) return;
      setState(() => _uploadingPhoto = true);
      final message = await widget.session.repository.updateProfilePhoto(photo);
      final refreshed = await widget.session.refreshUser();
      if (!mounted) return;
      setState(() => _user = refreshed);
      showMessage(context, message);
    } on ApiException catch (exception) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Foto belum diperbarui',
          message: exception.message,
        );
      }
    } catch (_) {
      if (mounted) {
        await showAppAlert(
          context,
          title: 'Foto belum diperbarui',
          message: 'Foto tidak dapat dipilih. Silakan coba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail =
        _user.intern ??
        _user.mentor ??
        _user.adminProfile ??
        const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: AppPageBackground(
        variant: 2,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            FeatureBanner(
              badge: _user.roleLabel,
              title: 'Profil dan perangkatmu',
              subtitle: 'Kelola informasi akun serta izin notifikasi aplikasi.',
              icon: Icons.person_rounded,
              supportingIcons: const [
                Icons.badge_outlined,
                Icons.notifications_active_outlined,
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _ProfileAvatar(
                      user: _user,
                      uploading: _uploadingPhoto,
                      onTap: _uploadingPhoto ? null : _changePhoto,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _user.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(_user.email),
                    const SizedBox(height: 10),
                    StatusPill(_user.roleLabel),
                    // const SizedBox(height: 9),
                    // TextButton.icon(
                    //   onPressed: _uploadingPhoto ? null : _changePhoto,
                    //   icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    //   label: const Text('Ubah foto profil'),
                    // ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeading(title: 'Informasi'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Nomor / Posisi',
                    value:
                        detail['number']?.toString() ??
                        detail['position']?.toString() ??
                        detail['role']?.toString() ??
                        '-',
                  ),
                  const Divider(height: 1, indent: 58),
                  _InfoTile(
                    icon: Icons.apartment_outlined,
                    label: 'Departemen',
                    value: detail['department']?.toString() ?? '-',
                  ),
                  if (detail['university'] != null) ...[
                    const Divider(height: 1, indent: 58),
                    _InfoTile(
                      icon: Icons.account_balance_outlined,
                      label: 'Universitas',
                      value: detail['university'].toString(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeading(title: 'Perangkat'),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Aktifkan notifikasi',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Termasuk pengingat Clock In dan Clock Out.',
                ),
                trailing: _askingPermission
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _askingPermission ? null : _enableNotifications,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Keluar dari akun'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.uploading,
    required this.onTap,
  });

  final AppUser user;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = ApiClient.publicFileUrl(user.profilePhoto);
    return Semantics(
      button: true,
      label: 'Ubah foto profil',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 98,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipOval(
                  child: ColoredBox(
                    color: AppColors.primary,
                    child: photoUrl == null
                        ? _AvatarInitials(user.initials)
                        : Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _AvatarInitials(user.initials),
                          ),
                  ),
                ),
              ),
              if (uploading)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x88000000),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  right: 0,
                  bottom: 3,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: AppColors.primaryDark,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 25,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    subtitle: Text(
      value,
      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
    ),
  );
}
