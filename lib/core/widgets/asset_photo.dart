import 'dart:io';

import 'package:flutter/material.dart';

import '../app_assets.dart';

/// Shows an asset photo, from wherever one actually exists.
///
/// Three sources, in order:
///
/// 1. the record's own `image_url` — a file path saved by the asset form, or
///    an old http URL from the Supabase era;
/// 2. the bundled photograph chosen by asset code, so the catalogue is never a
///    wall of grey placeholders;
/// 3. the category icon.
///
/// Every branch has an error builder. A bundled asset is compiled into the
/// APK, so it cannot 404 — but a local file can be deleted and a remote URL
/// can fail, and an unhandled image error paints a red box in release builds.
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

    final source = imageUrl;
    if (source != null && source.isNotEmpty) {
      if (source.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            source,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          ),
        );
      }

      // A photo picked in the app: stored as a file in the private documents
      // folder. `existsSync` is cheap and keeps a deleted file from throwing
      // during layout.
      final file = File(source);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      }
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
        'campaign' => Icons.campaign_rounded,
        'chair' => Icons.chair_rounded,
        'holiday_village' => Icons.holiday_village_rounded,
        'tv' => Icons.tv_rounded,
        'electrical_services' => Icons.electrical_services_rounded,
        _ => Icons.inventory_2_rounded,
      };
}