import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class PagePadding extends StatelessWidget {
  const PagePadding({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), child: child);
}

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({required this.child, this.variant = 0, super.key});

  final Widget child;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final colors = switch (variant % 3) {
      1 => const [Color(0xFFF8FAF1), Color(0xFFF0F7F2), Color(0xFFFFF8EC)],
      2 => const [Color(0xFFF2F8F3), Color(0xFFFFF7EE), Color(0xFFF4F7F4)],
      _ => const [Color(0xFFF4F9F4), Color(0xFFFAF7EF), Color(0xFFF1F7F3)],
    };
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        Positioned(
          top: -105,
          right: -90,
          child: _BackgroundOrb(
            size: 245,
            color: AppColors.accent.withValues(alpha: .10),
          ),
        ),
        Positioned(
          top: 210,
          left: -115,
          child: _BackgroundOrb(
            size: 210,
            color: AppColors.primary.withValues(alpha: .055),
          ),
        ),
        Positioned(
          bottom: -125,
          right: -95,
          child: _BackgroundOrb(
            size: 270,
            color: const Color(0xFFF59E0B).withValues(alpha: .055),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?action,
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, color.withValues(alpha: .075)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withValues(alpha: .16)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D17221C),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -24,
          bottom: -30,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .055),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class FeatureBanner extends StatelessWidget {
  const FeatureBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.action,
    this.supportingIcons = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final Widget? action;
  final List<IconData> supportingIcons;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF064928), AppColors.primary, Color(0xFF3D8A36)],
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2B006838),
          blurRadius: 26,
          offset: Offset(0, 13),
        ),
      ],
    ),
    child: Stack(
      children: [
        const Positioned(
          top: -54,
          right: -36,
          child: _BannerCircle(size: 132, color: Color(0x248CC63F)),
        ),
        const Positioned(
          bottom: -50,
          left: 92,
          child: _BannerCircle(size: 106, color: Color(0x18FFFFFF)),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDCEFE2),
                      height: 1.35,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
            const SizedBox(width: 14),
            FeatureIconCluster(
              mainIcon: icon,
              supportingIcons: supportingIcons,
            ),
          ],
        ),
      ],
    ),
  );
}

class FeatureIconCluster extends StatelessWidget {
  const FeatureIconCluster({
    required this.mainIcon,
    this.supportingIcons = const [],
    this.width = 106,
    this.height = 112,
    super.key,
  });

  final IconData mainIcon;
  final List<IconData> supportingIcons;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final first = supportingIcons.isNotEmpty
        ? supportingIcons.first
        : Icons.auto_awesome_rounded;
    final second = supportingIcons.length > 1
        ? supportingIcons[1]
        : Icons.check_rounded;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x33FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A003A20),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: width * .55,
              height: width * .55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.mint, Color(0xFFDDF1D8)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                mainIcon,
                color: AppColors.primary,
                size: width * .29,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 7,
            child: _MiniFeatureIcon(
              icon: first,
              color: const Color(0xFF2563EB),
              background: const Color(0xFFEAF1FF),
            ),
          ),
          Positioned(
            left: 7,
            bottom: 8,
            child: _MiniFeatureIcon(
              icon: second,
              color: AppColors.warning,
              background: const Color(0xFFFFF3D9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeatureIcon extends StatelessWidget {
  const _MiniFeatureIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 31,
    height: 31,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, color: color, size: 16),
  );
}

class _BannerCircle extends StatelessWidget {
  const _BannerCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {this.color, super.key});

  final String label;
  final Color? color;

  Color get _color {
    if (color != null) return color!;
    final normalized = label.toLowerCase();
    if (normalized.contains('reject') ||
        normalized.contains('tolak') ||
        normalized.contains('batal') ||
        normalized.contains('tidak masuk') ||
        normalized.contains('terlambat')) {
      return AppColors.danger;
    }
    if (normalized.contains('pending') ||
        normalized.contains('menunggu') ||
        normalized.contains('belum') ||
        normalized.contains('open')) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: _color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(48),
      child: CircularProgressIndicator(),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showAppAlert(
  BuildContext context, {
  required String message,
  String title = 'Periksa kembali',
  IconData icon = Icons.error_outline_rounded,
  Color color = AppColors.danger,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      icon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}
