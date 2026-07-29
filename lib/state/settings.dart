import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/haptics.dart';
import 'providers.dart';

/// Appearance and feedback preferences.
///
/// Both are read once at launch (before the first frame paints, so the app
/// never flashes the wrong theme) and written through on every change.

/// The chosen theme: System, Light, Dim or Dark.
///
/// This holds what was *asked for*, not what is painted — System has no
/// colours of its own and resolves against the device's setting at build time,
/// so a reader who changes their phone from light to dark sees the app follow
/// without anything here changing.
class ThemeController extends StateNotifier<OmniaThemeChoice> {
  ThemeController(this._ref) : super(OmniaThemeChoice.system) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final saved = await _ref.read(secureStoreProvider).readTheme();
    if (mounted) state = OmniaThemeChoiceX.fromWire(saved);
  }

  Future<void> set(OmniaThemeChoice choice) async {
    if (choice == state) return;
    state = choice;
    await _ref.read(secureStoreProvider).saveTheme(choice.wire);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, OmniaThemeChoice>(
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
