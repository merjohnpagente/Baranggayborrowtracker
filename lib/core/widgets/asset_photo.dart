import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/app_theme.dart';

/// Shows an asset photo, from wherever one actually exists.
///
/// Three sources, in order:
///
/// 1. the record's own `image_url` (a Supabase Storage URL, if uploaded);
/// 2. the bundled photograph chosen by asset code, so the catalogue is never a
///    wall of grey placeholders;
/// 3. the category icon.
///
/// Every branch has an error builder. A bundled asset is compiled into the
/// APK, so it cannot 404 — but a *remote* URL can, and an unhandled image
/// error paints a red box in release builds.
class AssetPhoto extends StatelessWidget {
  const AssetPhoto({
    super.key,
    this.imageUrl,
    this.assetCode,
    this.categoryIcon,
    this.width,
    this.height,
    this.radius = 14,
  });

  /// A remote URL, when the record has one.
  final String? imageUrl;

  /// The asset code (e.g. `VEH-001`), used to pick a bundled photograph.
  final String? assetCode;

  /// Fallback glyph, normally the category icon.
  final String? categoryIcon;

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        _glyphFor(categoryIcon),
        color: scheme.onSurfaceVariant,
        size: 28,
      ),
    );

    final remote = imageUrl;
    if (remote != null && remote.startsWith('http') && remote.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          remote,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder,
        ),
      );
    }

    final bundled = assetCode == null
        ? null
        : AppAssets.photoForAssetCode(assetCode!);
    if (bundled != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          bundled,
          width: width,
          height: height,
          fit: BoxFit.cover,
          // Unreachable in practice — a bundled asset is part of the APK —
          // but a renamed file would otherwise throw during layout.
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }

    return placeholder;
  }

  IconData _glyphFor(String? iconName) => switch (iconName) {
        'directions_car' => Icons.directions_car_filled_rounded,
        'sports_basketball' => Icons.sports_basketball_rounded,
        'celebration' => Icons.celebration_rounded,
        'campaign' => Icons.campaign_rounded,
        'power' => Icons.electrical_services_rounded,
        _ => Icons.inventory_2_rounded,
      };
}