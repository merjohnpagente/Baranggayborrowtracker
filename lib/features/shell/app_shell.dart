import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';

/// Bottom navigation wrapper. The `approvals` tab only appears for barangay
/// officials and administrators.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isOfficial = context.select<AuthProvider, bool>((a) => a.isOfficial);
    final destinations = <_Destination>[
      const _Destination('/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
      const _Destination('/assets', Icons.inventory_2_outlined,
          Icons.inventory_2_rounded, 'Assets'),
      const _Destination('/requests', Icons.assignment_outlined,
          Icons.assignment_rounded, 'My Requests'),
      if (isOfficial)
        const _Destination('/approvals', Icons.fact_check_outlined,
            Icons.fact_check_rounded, 'Approvals'),
      const _Destination(
          '/profile', Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    // Indexes shift by one when the approvals tab is hidden.
    final visibleCount = destinations.length;
    final rawIndex = navigationShell.currentIndex;
    final index = rawIndex >= visibleCount ? rawIndex - 1 : rawIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          // The branches are fixed (home, assets, requests, approvals,
          // profile) but the *visible* destinations drop approvals for
          // residents. Map the tap back to the branch it belongs to, or a
          // resident tapping Profile would land on the approvals branch.
          final branchIndex = isOfficial
              ? value
              : (value >= 3 ? value + 1 : value);
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.selectedIcon, this.label);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}