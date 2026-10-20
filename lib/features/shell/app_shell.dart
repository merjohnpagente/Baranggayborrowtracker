import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/motion.dart';
import '../../state/auth_provider.dart';

/// Bottom navigation wrapper. The `approvals` tab only appears for barangay
/// officials and administrators.
///
/// The shell is stateful so switching tabs can cross-fade the outgoing branch
/// into the incoming one. The branch itself stays alive inside
/// [StatefulNavigationShell]'s indexed stack, so scroll positions and form
/// state are not lost.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  int? _lastBranch;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      value: 1,
    );
    final curved = CurvedAnimation(
      parent: _motion,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0.55, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _animateBranchChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduceMotion) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    });
  }

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
      const _Destination('/profile', Icons.person_outline_rounded,
          Icons.person_rounded, 'Profile'),
    ];

    // Indexes shift by one when the approvals tab is hidden.
    final visibleCount = destinations.length;
    final rawIndex = widget.navigationShell.currentIndex;
    final index = rawIndex >= visibleCount ? rawIndex - 1 : rawIndex;

    _reduceMotion = Motion.reduced(context);
    if (_lastBranch == null) {
      _lastBranch = rawIndex;
    } else if (_lastBranch != rawIndex) {
      _lastBranch = rawIndex;
      _animateBranchChange();
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: widget.navigationShell,
        ),
      ),
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
          widget.navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == widget.navigationShell.currentIndex,
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
