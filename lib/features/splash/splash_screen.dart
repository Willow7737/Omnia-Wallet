import 'package:flutter/material.dart';

import '../../core/brand/brand.dart';

/// Shown for the brief moment while we determine whether a wallet exists on
/// this device, so a first-time user never flashes past the Home screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            BrandMark(size: 72),
            SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
