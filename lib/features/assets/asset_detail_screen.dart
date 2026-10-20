import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/qr_payload.dart';
import '../../data/models/asset.dart';
import '../../data/repositories/asset_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/inventory_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/asset_photo.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../qr/qr_display_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  Asset? _asset;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = context.read<InventoryProvider>().byId(widget.assetId);
    if (cached != null) setState(() => _asset = cached);
    final repository = context.read<AssetRepository>();
    try {
      final fresh = await repository.fetchAsset(widget.assetId);
      if (mounted) {
        setState(() {
          _asset = fresh;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(AssetStatus status) async {
    final repository = context.read<AssetRepository>();
    try {
      await repository.setAssetStatus(widget.assetId, status);
      await _load();
      if (!mounted) return;
      AppToast.success(context, 'Marked as ${status.label.toLowerCase()}.');
    } catch (error) {
      if (mounted) AppToast.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final asset = _asset;

    if (_loading && asset == null) {
      return const Scaffold(body: LoadingView());
    }
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Asset not found',
          message: 'It may have been removed from the catalogue.',
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailHeader(
            onBack: () => context.pop(),
            child: _HeaderImage(asset: asset),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  asset.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip.asset(
                      context,
                      asset.status.value,
                      asset.status.label,
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: asset.condition.label,
                      color: theme.colorScheme.outline,
                      icon: Icons.build_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${asset.category.label} · ${asset.code}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (asset.description != null &&
                    asset.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(asset.description!, style: theme.textTheme.bodyMedium),
                ],
                const SectionHeader(title: 'DETAILS'),
                InfoRow(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: asset.location ?? 'Not specified',
                ),
                InfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Asset code',
                  value: asset.code,
                ),
                InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantity',
                  value: '${asset.quantity}',
                ),
                if (asset.plateNumber != null)
                  InfoRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Plate number',
                    value: asset.plateNumber!,
                  ),
                if (asset.maintenanceNote != null) ...[
                  const SectionHeader(title: 'MAINTENANCE NOTE'),
                  Text(
                    asset.maintenanceNote!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (auth.isOfficial) ...[
                  const SectionHeader(title: 'OFFICIAL CONTROLS'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set status',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: AssetStatus.values
                                .map(
                                  (status) => ChoiceChip(
                                    label: Text(status.label),
                                    selected: asset.status == status,
                                    onSelected: (_) => _setStatus(status),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QrDisplayScreen(
                        title: asset.name,
                        payload: QrPayload.forAsset(asset.id),
                        subtitle:
                            'Print this on a sticker and paste it on the item.',
                        footer: 'Asset code ${asset.code}',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Show asset QR code'),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (auth.isOfficial) ...[
                IconButton.filledTonal(
                  tooltip: 'Edit asset',
                  onPressed: () => context.push('/assets/${asset.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: asset.canRequest
                      ? () => context.push('/requests/new?asset=${asset.id}')
                      : null,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                    asset.canRequest
                        ? 'Request this item'
                        : asset.isArchived
                            ? 'Archived'
                            : 'Currently unavailable',
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

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    // AssetPhoto resolves the record's uploaded URL first, then a bundled
    // photograph by asset code, then the category icon — so this header is
    // never an empty grey band.
    return SizedBox.expand(
      child: AssetPhoto(
        imageUrl: asset.imageUrl,
        assetCode: asset.code,
        categoryIcon: asset.category.icon,
        radius: 0,
      ),
    );
  }
}