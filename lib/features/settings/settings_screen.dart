import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_version.dart';
import '../../core/widgets/common.dart';
import '../../state/auth_provider.dart';

/// Settings and about: version, developer, GitHub and the coffee jar.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Read the installed version from the build, not a hardcoded string.
    AppVersion.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _openGithub() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(AppConfig.githubUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('No browser handled the link.');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }

  Future<void> _copyGcash() async {
    await Clipboard.setData(const ClipboardData(text: AppConfig.gcashDigits));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('GCash number copied — ${AppConfig.gcashNumber}'),
      ),
    );
  }

  Future<void> _copyVersion() async {
    await Clipboard.setData(
      ClipboardData(text: 'v${AppVersion.label}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Version copied')),
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                  ),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (value) =>
                      value == next.text ? null : 'Passwords do not match',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: current.text,
      newPassword: next.text,
    );
    if (!mounted) return;
    if (ok) {
      AppToast.success(context, 'Password changed.');
    } else if (auth.error != null) {
      AppToast.error(context, auth.error!);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionHeader(title: 'ACCOUNT'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Change password'),
                  subtitle: const Text('Stored only on this phone'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'ABOUT'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.assignment_rounded),
                  title: const Text(AppConfig.appName),
                  subtitle: const Text('Borrow • Reserve • Return'),
                ),
                ListTile(
                  leading: const Icon(Icons.numbers_rounded),
                  title: const Text('Version'),
                  subtitle: Text(
                    AppVersion.isLoaded
                        ? 'v${AppVersion.label}'
                        : 'Reading…',
                  ),
                  trailing: AppVersion.isLoaded
                      ? IconButton(
                          tooltip: 'Copy version',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: _copyVersion,
                        )
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text('Developed by ${AppConfig.developerBrand}'),
                  subtitle: const Text(AppConfig.developerName),
                ),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('GitHub'),
                  subtitle: const Text('github.com/${AppConfig.githubHandle}'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: _openGithub,
                ),
                ListTile(
                  leading: const Icon(Icons.coffee_rounded),
                  title: const Text('Buy me a coffee'),
                  subtitle: const Text(
                    'GCash ${AppConfig.gcashNumber} — a broke developer says '
                    'thank you.',
                  ),
                  trailing: const Icon(Icons.copy_all_rounded, size: 18),
                  onTap: _copyGcash,
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text('Storage'),
                  subtitle: const Text(
                    'On this device only. No account or record leaves the '
                    'phone.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No internet connection is needed. Back up your data by keeping '
            'the phone safe — there is no cloud copy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
