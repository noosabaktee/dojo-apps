import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/app_user.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({required this.user, required this.onOpen, super.key});

  final AppUser user;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final features = <_MenuItem>[
      if (user.isIntern)
        const _MenuItem('evaluation', 'Rapor Intern', Icons.school_outlined),
      if (user.isAdmin) ...const [
        _MenuItem(
          'calendar',
          'Calendar Sharing',
          Icons.calendar_month_outlined,
        ),
        _MenuItem('evaluation', 'Rapor Intern', Icons.school_outlined),
        _MenuItem('report', 'Report', Icons.analytics_outlined),
      ],
      if (user.isMentor)
        const _MenuItem('report', 'Report', Icons.analytics_outlined),
      const _MenuItem(
        'notifications',
        'Notifikasi',
        Icons.notifications_none_rounded,
      ),
      const _MenuItem(
        'profile',
        'Profil & Perangkat',
        Icons.person_outline_rounded,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Menu', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text('Akses fitur lainnya dan pengaturan akun ${user.roleLabel}.'),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                child: Text(
                  user.initials,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user.roleLabel,
                      style: const TextStyle(color: Color(0xFFDCEFE2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...features.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 21),
              ),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () => onOpen(item.key),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  const _MenuItem(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}
