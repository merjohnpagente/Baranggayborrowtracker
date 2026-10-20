import 'dart:async';

import 'package:flutter/material.dart';

/// Motion helpers shared by the whole app.
///
/// The animations here are short, one-shot and subtle on purpose: the app
/// should feel responsive, not like it is making the user wait for effects.
class Motion {
  const Motion._();

  /// Respect the device's "remove animations" accessibility setting.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// A small cascade for items entering a list, capped so a long list still
  /// appears promptly.
  static Duration stagger(
    int index, {
    int stepMs = 40,
    int maxSteps = 6,
  }) {
    final steps = index <= 0 ? 0 : (index > maxSteps ? maxSteps : index);
    return Duration(milliseconds: steps * stepMs);
  }
}

/// Fades and lifts [child] into place once, after an optional [delay].
///
/// Used for cards and page sections. Because it is a stateful widget, an item
/// already on screen never replays its entrance when the list refreshes; new
/// items animate when they are inserted.
class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 0.055),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
