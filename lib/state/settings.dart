import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/haptics.dart';
import 'providers.dart';

/// Appearance and feedback preferences.
///
/// Both are read once at launch (before the first frame paints, so the app
/// never flashes the wrong theme) and written through on every change.

/// The active theme: Light, Dim or Dark. Bluesky offers exactly these three.
class ThemeController extends StateNotifier<OmniaThemeName> {
  ThemeController(this._ref) : super(OmniaThemeName.dim) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final saved = await _ref.read(secureStoreProvider).readTheme();
    state = OmniaThemeNameX.fromWire(saved);
  }

  Future<void> set(OmniaThemeName name) async {
    if (name == state) return;
    state = name;
    await _ref.read(secureStoreProvider).saveTheme(name.wire);
  }
}

final themeProvider =
    StateNotifierProvider<ThemeController, OmniaThemeName>(
  ThemeController.new,
);

/// Whether haptic feedback fires at all. Mirrored into [Haptics.enabled],
/// which every call site checks, so a single flip silences the whole app
/// without touching individual widgets.
class HapticsController extends StateNotifier<bool> {
  HapticsController(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final on = await _ref.read(secureStoreProvider).readHapticsEnabled();
    state = on;
    Haptics.enabled = on;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    // Set before persisting so the confirming tick below actually plays when
    // the user is switching the feature back *on*.
    Haptics.enabled = enabled;
    if (enabled) Haptics.selection();
    await _ref.read(secureStoreProvider).saveHapticsEnabled(enabled);
  }
}

final hapticsEnabledProvider =
    StateNotifierProvider<HapticsController, bool>(HapticsController.new);
