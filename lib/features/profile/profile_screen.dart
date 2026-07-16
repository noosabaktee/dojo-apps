import 'package:flutter/material.dart';

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
  bool _askingPermission = false;

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
      await widget.session.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail =
        widget.user.intern ??
        widget.user.mentor ??
        widget.user.adminProfile ??
        const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      widget.user.initials,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.user.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.user.email),
                  const SizedBox(height: 10),
                  StatusPill(widget.user.roleLabel),
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
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar dari akun'),
          ),
        ],
      ),
    );
  }
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
