import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';

/// Shown when the APK was built without Supabase credentials. It tells the
/// user (or the barangay IT person) exactly what is missing.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link_off_rounded,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Database not connected',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'This build was made without Supabase credentials. Rebuild '
                  'the app with the keys from your Supabase project '
                  '(Project Settings → API).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _CodeBlock(
                  label: 'GitHub Actions',
                  value: 'Settings → Secrets and variables → Actions\n'
                      'SUPABASE_URL\nSUPABASE_ANON_KEY\nBARANGAY_NAME',
                ),
                const SizedBox(height: 16),
                _CodeBlock(
                  label: 'Local run',
                  value: 'flutter run \\\n'
                      '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                      '  --dart-define=SUPABASE_ANON_KEY=eyJ... \\\n'
                      '  --dart-define=BARANGAY_NAME="Barangay San Jose"',
                ),
                const SizedBox(height: 24),
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Splash screen shown while the stored session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_rounded,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              AppConfig.appName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen message used after signing up when email confirmation is on.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(Icons.mark_email_read_outlined,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Check your inbox',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a confirmation link to $email. Open it, then sign in '
                'to start borrowing.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}