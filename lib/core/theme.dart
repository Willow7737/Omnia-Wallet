import 'package:flutter/material.dart';

/// Semantic accent colors that Material's [ColorScheme] doesn't cover
/// (success / warning), exposed as a [ThemeExtension] so widgets can read
/// them theme-aware in both light and dark.
@immutable
class OmniaColors extends ThemeExtension<OmniaColors> {
  const OmniaColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.positive,
    required this.negative,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;

  /// For amounts: incoming/credit vs outgoing/debit.
  final Color positive;
  final Color negative;

  // Discord-inspired semantics: green for incoming/success, red for
  // outgoing/spend — Send and Receive read differently at a glance.
  static const light = OmniaColors(
    success: Color(0xFF23A55A),
    onSuccess: Colors.white,
    successContainer: Color(0xFFD8F3E3),
    warning: Color(0xFFF0B232),
    positive: Color(0xFF23A55A),
    negative: Color(0xFFDA373C),
  );

  static const dark = OmniaColors(
    success: Color(0xFF23A55A),
    onSuccess: Colors.white,
    successContainer: Color(0xFF1E3B2C),
    warning: Color(0xFFF0B232),
    positive: Color(0xFF3BA55D),
    negative: Color(0xFFF23F43),
  );

  @override
  OmniaColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? positive,
    Color? negative,
  }) =>
      OmniaColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        successContainer: successContainer ?? this.successContainer,
        warning: warning ?? this.warning,
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
      );

  @override
  OmniaColors lerp(ThemeExtension<OmniaColors>? other, double t) {
    if (other is! OmniaColors) return this;
    return OmniaColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

/// Convenience accessor: `context.omnia.success`.
extension OmniaThemeX on BuildContext {
  OmniaColors get omnia => Theme.of(this).extension<OmniaColors>()!;
}

/// Omnia design language 2.0 — Discord-inspired: a blurple accent over
/// calm layered neutrals, set entirely in Inter.
class OmniaTheme {
  OmniaTheme._();

  /// The accent ("blurple").
  static const Color blue = Color(0xFF5865F2);

  // Light neutrals (Discord light mode: white cards over cool grey).
  static const Color ink = Color(0xFF313338);
  static const Color paper = Color(0xFFF9F9FA);

  // Dark neutrals, layered exactly like Discord: app bg -> card -> input.
  static const Color darkBg = Color(0xFF1E1F22);
  static const Color darkCard = Color(0xFF2B2D31);
  static const Color darkInput = Color(0xFF383A40);
  static const Color darkText = Color(0xFFDBDEE1);

  // Tabular figures keep balances and amounts from shifting width as they
  // animate/update.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
    ).copyWith(
      surface: paper,
      primary: blue,
      onSurface: ink,
      surfaceContainerHighest: const Color(0xFFEBEDEF),
    );
    return _base(scheme, OmniaColors.light, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: darkBg,
      primary: blue,
      onPrimary: Colors.white,
      onSurface: darkText,
      surfaceContainerHighest: darkCard,
    );
    return _base(scheme, OmniaColors.dark, Brightness.dark);
  }

  static ThemeData _base(
    ColorScheme scheme,
    OmniaColors omnia,
    Brightness brightness,
  ) {
    final base = ThemeData(brightness: brightness, fontFamily: 'Inter');
    final text = base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      extensions: [omnia],
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          fontFeatures: _tabular,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontFeatures: _tabular,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        toolbarHeight: 72,
        // Screen titles (Profile, Send UBC, History, Settings, Governance…)
        // read as page headings: large and heavy.
        titleTextStyle: text.headlineMedium?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
      ),
    );
  }
}
