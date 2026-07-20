import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/app_user.dart';
import '../../widgets/common.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    required this.user,
    required this.onOpen,
    required this.unreadCount,
    super.key,
  });

  final AppUser user;
  final ValueChanged<String> onOpen;
  final ValueListenable<int> unreadCount;

  @override
  Widget build(BuildContext context) {
    final features = <_MenuItem>[
      if (user.isIntern) ...const [
        _MenuItem('wfh', 'Pengajuan WFH', Icons.home_work_outlined),
        _MenuItem('evaluation', 'Rapor Intern', Icons.school_outlined),
      ],
      if (user.isAdmin) ...const [
        _MenuItem(
          'calendar',
          'Calendar Sharing',
          Icons.calendar_month_outlined,
        ),
        _MenuItem('evaluation', 'Rapor Intern', Icons.school_outlined),
      ],
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
        const SizedBox(height: 18),
        const FeatureBanner(
          badge: 'Pusat fitur',
          title: 'Semua kebutuhan dalam satu menu',
          subtitle: 'Buka pengajuan, notifikasi, rapor, dan pengaturan akunmu.',
          icon: Icons.grid_view_rounded,
          supportingIcons: [
            Icons.notifications_none_rounded,
            Icons.person_outline_rounded,
          ],
        ),
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
              _MenuAvatar(user: user),
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
              trailing: item.key == 'notifications'
                  ? ValueListenableBuilder<int>(
                      valueListenable: unreadCount,
                      builder: (_, count, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 0) _UnreadCountBadge(count: count),
                          if (count > 0) const SizedBox(width: 7),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    )
                  : const Icon(
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

class _MenuAvatar extends StatelessWidget {
  const _MenuAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = ApiClient.publicFileUrl(user.profilePhoto);
    return ClipOval(
      child: SizedBox.square(
        dimension: 54,
        child: ColoredBox(
          color: Colors.white,
          child: photoUrl == null
              ? _initials()
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _initials(),
                ),
        ),
      ),
    );
  }

  Widget _initials() => Center(
    child: Text(
      user.initials,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => UnconstrainedBox(
    child: SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: count > 99 ? 8.5 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MenuItem {
  const _MenuItem(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}
