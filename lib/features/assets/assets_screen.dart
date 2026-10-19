import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/asset.dart';
import '../../state/auth_provider.dart';
import '../../state/inventory_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    context.read<InventoryProvider>().setSearch(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) context.read<InventoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Assets'),
        actions: [
          if (auth.isOfficial)
            IconButton(
              tooltip: 'Add asset',
              onPressed: () => context.push('/assets/new'),
              icon: const Icon(Icons.add_box_outlined),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or code',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: inventory.search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              context.read<InventoryProvider>().setSearch('');
                              context.read<InventoryProvider>().load();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      label: const Text('Available only'),
                      selected: inventory.onlyAvailable,
                      onSelected: (_) =>
                          context.read<InventoryProvider>().toggleOnlyAvailable(),
                    ),
                    const SizedBox(width: 8),
                    ...AssetStatus.values.map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status.label),
                          selected: inventory.status == status,
                          onSelected: (selected) => context
                              .read<InventoryProvider>()
                              .setStatus(selected ? status : null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: auth.isOfficial
          ? FloatingActionButton(
              onPressed: () => context.push('/assets/new'),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => context.read<InventoryProvider>().refresh(),
        child: inventory.loading && inventory.assets.isEmpty
            ? const LoadingView(label: 'Loading assets…')
            : inventory.assets.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: inventory.hasFilters
                              ? 'No matching assets'
                              : 'No assets yet',
                          message: inventory.hasFilters
                              ? 'Try a different search or clear the filters.'
                              : 'Barangay officials can add the first item.',
                          action: inventory.hasFilters
                              ? FilledButton.tonal(
                                  onPressed: () {
                                    _searchController.clear();
                                    context
                                        .read<InventoryProvider>()
                                        .clearFilters();
                                  },
                                  child: const Text('Clear filters'),
                                )
                              : null,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: inventory.assets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final asset = inventory.assets[index];
                      return AssetCard(
                        asset: asset,
                        onTap: () => context.push('/assets/${asset.id}'),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: inventory.categories.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: inventory.category == null,
                      onSelected: (_) =>
                          context.read<InventoryProvider>().setCategory(null),
                    ),
                    const SizedBox(width: 8),
                    ...inventory.categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category.label),
                          selected: inventory.category == category,
                          onSelected: (_) => context
                              .read<InventoryProvider>()
                              .setCategory(category),
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