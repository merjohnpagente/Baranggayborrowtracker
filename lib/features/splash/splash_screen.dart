import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Barangay Borrow Tracker splash.
///
/// The idea is a barangay asset tag rather than a generic app logo: the tag
/// settles into place, a green "ready" stamp pops on, then a short
/// Request → Borrow → Return journey marks the time before the router takes
/// over. Everything is finite, so the CPU is idle once the splash is done.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0A3556);
  static const _deep = Color(0xFF04121F);
  static const _accent = Color(0xFF2E8BD0);
  static const _mint = Color(0xFF64DDA4);
  static const _paper = Color(0xFFF8FBFD);
  static const _ink = Color(0xFF0E2B42);

  Timer? _timer;
  bool _done = false;

  late final AnimationController _intro;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardScale;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;
  late final Animation<double> _stampFade;
  late final Animation<double> _stampScale;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _cardFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
          ),
        );
    _cardScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _copyFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 1, curve: Curves.easeOut),
    );
    _copySlide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.32, 1, curve: Curves.easeOutCubic),
          ),
        );
    _stampFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.56, 0.74, curve: Curves.easeOut),
    );
    _stampScale = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.56, 1, curve: Curves.elasticOut),
      ),
    );

    // Wait for the first painted frame before starting, so a cold start never
    // swallows the entrance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _done) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
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
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: _deep,
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
                  colors: [_navy, _deep],
                ),
              ),
            ),
            // Large, quiet outlines — a geometry that belongs to this splash
            // rather than the circular colour blooms of the previous one.
            Positioned(
              top: -110,
              right: -120,
              child: Transform.rotate(
                angle: 0.26,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(78),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -130,
              child: Transform.rotate(
                angle: -0.32,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(92),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: ScaleTransition(
                          scale: _cardScale,
                          child: _BorrowTag(
                            stampFade: _stampFade,
                            stampScale: _stampScale,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    FadeTransition(
                      opacity: _copyFade,
                      child: SlideTransition(
                        position: _copySlide,
                        child: Column(
                          children: [
                            const Text(
                              AppConfig.appName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 11),
                            Container(
                              width: 26,
                              height: 3,
                              decoration: BoxDecoration(
                                color: _mint,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 11),
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
                    ),
                    const Spacer(flex: 4),
                    _Journey(reduceMotion: reduceMotion),
                    const SizedBox(height: 22),
                    const Text(
                      'Saved on this device — works offline',
                      style: TextStyle(color: Colors.white54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'By ${AppConfig.developerBrand}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
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

/// A barangay asset tag: two offset cards, a category icon, a status pill and
/// a stamp that lands after the card has settled.
class _BorrowTag extends StatelessWidget {
  const _BorrowTag({required this.stampFade, required this.stampScale});

  final Animation<double> stampFade;
  final Animation<double> stampScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 238,
      height: 158,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 16,
            top: 16,
            right: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.055,
              child: Container(
                decoration: BoxDecoration(
                  color: _SplashScreenState._accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
              decoration: BoxDecoration(
                color: _SplashScreenState._paper,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 28,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _SplashScreenState._navy,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _SplashScreenState._mint.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Color(0xFF147A4D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'READY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFF147A4D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 9,
                    width: 132,
                    decoration: BoxDecoration(
                      color: _SplashScreenState._ink.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 7,
                    width: 90,
                    decoration: BoxDecoration(
                      color: _SplashScreenState._ink.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var index = 0; index < 4; index++)
                        Container(
                          width: index == 0 ? 24 : 16,
                          height: 4,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: _SplashScreenState._ink.withValues(
                              alpha: index == 0 ? 0.55 : 0.16,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: stampFade,
              child: ScaleTransition(
                scale: stampScale,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _SplashScreenState._mint,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _SplashScreenState._deep,
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _SplashScreenState._deep,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-step request journey. It replaces the usual determinate loading bar
/// with something specific to borrowing: request, use, return.
class _Journey extends StatelessWidget {
  const _Journey({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppConfig.splashDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final active = value < 0.42
            ? 0
            : value < 0.82
            ? 1
            : 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _JourneyStep(
              icon: Icons.event_available_rounded,
              label: 'Request',
              active: active >= 0,
              done: active >= 1,
            ),
            _JourneyTrack(fill: (value / 0.42).clamp(0, 1).toDouble()),
            _JourneyStep(
              icon: Icons.outbox_rounded,
              label: 'Borrow',
              active: active >= 1,
              done: active >= 2,
            ),
            _JourneyTrack(fill: ((value - 0.42) / 0.40).clamp(0, 1).toDouble()),
            _JourneyStep(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Return',
              active: active >= 2,
              done: active >= 2,
            ),
          ],
        );
      },
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active ? _SplashScreenState._mint : Colors.white38;
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? _SplashScreenState._mint.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border.all(color: color, width: 1.3),
            ),
            child: Icon(
              done ? Icons.check_rounded : icon,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _JourneyTrack extends StatelessWidget {
  const _JourneyTrack({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 21),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fill,
        child: Container(
          decoration: BoxDecoration(
            color: _SplashScreenState._mint,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
