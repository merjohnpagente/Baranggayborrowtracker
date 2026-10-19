import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user_profile.dart';
import '../../state/auth_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/empty_state.dart';

/// Admin only: activate official accounts and change roles.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserProfile> _users = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<AuthProvider>().listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeRole(UserProfile user, UserRole role) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.changeRole(userId: user.id, role: role);
    if (!mounted) return;
    if (ok) {
      AppToast.success(context, '${user.fullName} is now ${role.label}.');
      _load();
    } else if (auth.error != null) {
      AppToast.error(context, auth.error!);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load users',
                  message: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            user.avatar,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.role.label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<UserRole>(
                              tooltip: 'Change role',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (role) => _changeRole(user, role),
                              itemBuilder: (context) => [
                                for (final role in UserRole.values)
                                  PopupMenuItem<UserRole>(
                                    value: role,
                                    child: Row(
                                      children: [
                                        Icon(
                                          role == user.role
                                              ? Icons.check_rounded
                                              : Icons.circle_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(role.label),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}