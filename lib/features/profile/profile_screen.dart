import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/validators.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_provider.dart';
import '../../state/inventory_provider.dart';
import '../../state/requests_provider.dart';
import '../../core/widgets/asset_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_chip.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    if (profile == null) {
      return const Scaffold(body: LoadingView());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(profile: profile, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(
                              label: profile.role.label,
                              color: theme.colorScheme.primary,
                              icon: Icons.badge_outlined,
                              dense: true,
                            ),
                            if (profile.phone != null)
                              StatusChip(
                                label: profile.phone!,
                                color: theme.colorScheme.outline,
                                icon: Icons.call_outlined,
                                dense: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (profile.purok != null && profile.purok!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: InfoRow(
                  icon: Icons.home_outlined,
                  label: 'Purok',
                  value: profile.purok!,
                ),
              ),
            ),
          ],
          const SectionHeader(title: 'ACCOUNT'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit details'),
                  onTap: () => _editProfile(context, profile),
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Borrow history'),
                  subtitle: const Text('Completed, declined and withdrawn'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/history'),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: const Text('Notifications'),
                  subtitle: const Text('Approvals, due dates and returns'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/notifications'),
                ),
                if (auth.isAdmin)
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined),
                    title: const Text('Manage users'),
                    subtitle: const Text('Set roles and activate accounts'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/profile/users'),
                  ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh data'),
                  onTap: () async {
                    await Future.wait([
                      context.read<InventoryProvider>().refresh(),
                      context
                          .read<RequestsProvider>()
                          .refreshAll(isOfficial: auth.isOfficial),
                      auth.reloadProfile(),
                    ]);
                    if (context.mounted) {
                      AppToast.success(context, 'Data refreshed.');
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'ABOUT'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: const [
                  InfoRow(
                    icon: Icons.apartment_rounded,
                    label: 'Barangay',
                    value: AppConfig.barangayName,
                  ),
                  InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'App',
                    value: AppConfig.appName,
                  ),
                  const InfoRow(
                    icon: Icons.shield_outlined,
                    label: 'Account role',
                    value: 'Access is decided by the barangay office',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'You will need your email and password to sign in again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Stay'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final purokController = TextEditingController(text: profile.purok ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit details'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: Validators.name,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Mobile number'),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: purokController,
                  decoration: const InputDecoration(labelText: 'Purok'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.saveProfile(
      fullName: nameController.text.trim(),
      phone: phoneController.text.trim(),
      purok: purokController.text.trim(),
    );
    if (!context.mounted) return;
    if (ok) {
      AppToast.success(context, 'Profile updated.');
    } else if (auth.error != null) {
      AppToast.error(context, auth.error!);
      auth.clearError();
    }
  }
}