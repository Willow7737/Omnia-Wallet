import 'package:flutter/material.dart';

import '../../core/brand/brand.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// Shown for the brief moment while we determine whether a wallet exists on
/// this device, so a first-time user never flashes past the Home screen.
///
/// The mark breathes rather than sitting next to a spinner: on a launch that
/// resolves in 200 ms a spinner only ever registers as a flicker.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final curved = CurvedAnimation(parent: _c, curve: Motion.standard);

    return Scaffold(
      backgroundColor: o.bg,
      body: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: BrandMark(size: 64, color: o.text),
          ),
        ),
      ),
    );
  }
}
