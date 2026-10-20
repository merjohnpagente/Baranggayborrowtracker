import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Splash: the mark settles in on a full-bleed navy field, then the app moves
/// on. Same shape as the ClassCast splash — gradient, wave of colour, finite
/// progress bar and the MerjDev credit last — adapted to this app's palette.
///
/// Everything here is finite on purpose. A looping animation would keep the
/// CPU awake during the one moment the app has nothing to do, and tapping
/// anywhere skips straight to the router.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _navy = Color(0xFF103B63);
  static const _navyDark = Color(0xFF0A2440);
  static const _accent = Color(0xFF1769AA);

  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Wait for the splash to have actually been painted, then hold it long
    // enough to read. A plain Timer from initState can fire before the first
    // frame on a slow cold start, so the splash is never seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _done) return;
      _timer = Timer(AppConfig.splashDuration, _finish);
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navy, _navyDark],
                ),
              ),
            ),
            // Soft light blooms keep the full-screen navy from reading as a
            // stuck loading state.
            const Positioned(
              top: -90,
              right: -70,
              child: _Bloom(size: 280, color: _accent, opacity: 0.35),
            ),
            const Positioned(
              bottom: -120,
              left: -90,
              child: _Bloom(size: 320, color: _accent, opacity: 0.22),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.84, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0).toDouble(),
                          child: child,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 32,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              size: 52,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            AppConfig.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Borrow  •  Reserve  •  Return',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A determinate sweep rather than an endless spinner:
                        // it fills across exactly the time the splash is up.
                        SizedBox(
                          width: 120,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: AppConfig.splashDuration,
                            curve: Curves.easeInOutCubic,
                            builder: (context, value, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Saved on this device — works offline',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'By ${AppConfig.developerBrand}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}
