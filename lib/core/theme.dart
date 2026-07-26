import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/tokens.dart';

export 'design/tokens.dart';

/// The ALF "theme atoms" — the semantic layer between the raw palette ramps
/// and the widgets. Read it as `context.omnia`.
///
/// Every widget in the app should reach for one of these rather than a raw
/// ramp index, so a palette change lands everywhere at once.
@immutable
class OmniaColors extends ThemeExtension<OmniaColors> {
  const OmniaColors({required this.palette, required this.isDark});

  final OmniaPalette palette;
  final bool isDark;

  // ---- text ----

  /// Primary body/heading text.
  Color get text => palette.contrast1000;

  /// De-emphasised text: subtitles, secondary rows.
  Color get textMedium => palette.contrast700;

  /// Quietest text: timestamps, metadata, helper copy.
  Color get textLow => palette.contrast400;

  /// Slightly stronger than [textMedium], for text that still needs to read.
  Color get textHigh => palette.contrast900;

  /// Text on an inverted (filled) surface.
  Color get textInverted => palette.contrast0;

  /// Links and interactive text. The dark ramps are inverted, so 600 is the
  /// *lighter* blue there — this is deliberate, and matches ALF.
  Color get link => isDark ? palette.primary600 : palette.primary500;

  // ---- surfaces ----

  /// The page background.
  Color get bg => palette.contrast0;

  /// The first step up from the page — inputs, quiet chips.
  Color get bg25 => palette.contrast25;

  /// Secondary button fill, tonal surfaces.
  Color get bg50 => palette.contrast50;

  /// Pressed state of [bg50].
  Color get bg100 => palette.contrast100;

  Color get bg200 => palette.contrast200;

  // ---- borders ----

  /// The workhorse hairline. Every divider in the app is this colour.
  Color get borderLow => palette.contrast100;

  Color get borderMedium => palette.contrast200;

  Color get borderHigh => palette.contrast300;

  // ---- semantics ----

  Color get accent => palette.primary500;
  Color get accentPressed => palette.primary600;
  Color get accentDisabled => palette.primary200;

  /// Incoming / confirmed / good.
  Color get positive => isDark ? palette.positive400 : palette.positive600;
  Color get positiveSurface => palette.positive25;

  /// Outgoing / destructive / bad.
  Color get negative => isDark ? palette.negative400 : palette.negative600;
  Color get negativeSolid => palette.negative500;
  Color get negativeSurface => palette.negative25;

  /// Kept as aliases so semantic intent reads clearly at the call site.
  Color get success => positive;
  Color get warning => palette.yellow;

  /// The heart / like colour.
  Color get like => palette.pink;

  /// Scrim behind modals and sheets.
  Color get scrim => OmniaPalette.black.withValues(alpha: isDark ? 0.6 : 0.35);

  /// Shadow tint. ALF uses 0.1 opacity in light, 0.4 in dark.
  Color get shadow => OmniaPalette.black.withValues(alpha: isDark ? 0.4 : 0.1);

  /// ALF `shadow_md`, translated to Flutter.
  List<BoxShadow> get shadowMd => [
        BoxShadow(color: shadow, blurRadius: 15, offset: const Offset(0, 10)),
        BoxShadow(color: shadow, blurRadius: 6, offset: const Offset(0, 4)),
      ];

  /// ALF `shadow_sm`.
  List<BoxShadow> get shadowSm => [
        BoxShadow(color: shadow, blurRadius: 6, offset: const Offset(0, 4)),
      ];

  @override
  OmniaColors copyWith({OmniaPalette? palette, bool? isDark}) => OmniaColors(
        palette: palette ?? this.palette,
        isDark: isDark ?? this.isDark,
      );

  @override
  OmniaColors lerp(ThemeExtension<OmniaColors>? other, double t) {
    if (other is! OmniaColors) return this;
    List<Color> ramp(List<Color> a, List<Color> b) => [
          for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
        ];
    return OmniaColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      palette: OmniaPalette(
        contrast: ramp(palette.contrast, other.palette.contrast),
        primary: ramp(palette.primary, other.palette.primary),
        positive: ramp(palette.positive, other.palette.positive),
        negative: ramp(palette.negative, other.palette.negative),
        pink: Color.lerp(palette.pink, other.palette.pink, t)!,
        yellow: Color.lerp(palette.yellow, other.palette.yellow, t)!,
      ),
    );
  }
}

/// `context.omnia.textLow` — the way every widget reads the palette.
///
/// Falls back to the matching default palette when the extension is absent,
/// rather than null-checking. Every widget in the app reaches for this, so a
/// hard crash here would mean none of them could be dropped into a plain
/// `MaterialApp` — in a widget test, a golden, or a preview harness.
extension OmniaThemeX on BuildContext {
  OmniaColors get omnia {
    final theme = Theme.of(this);
    final extension = theme.extension<OmniaColors>();
    if (extension != null) return extension;
    return theme.brightness == Brightness.dark
        ? OmniaColors(palette: OmniaPalette.subdued.invert(), isDark: true)
        : const OmniaColors(palette: OmniaPalette.defaults, isDark: false);
  }
}

/// Builds the three ALF themes (Light / Dim / Dark) as Flutter [ThemeData].
///
/// The result is deliberately *flat*: no elevation anywhere, no ink ripples,
/// hairline borders instead of filled cards, and pill-shaped buttons. See
/// `docs/DESIGN.md`.
class OmniaTheme {
  OmniaTheme._();

  /// Accent blue, `primary_500`.
  static const Color blue = Color(0xFF006AFF);

  static ThemeData of(OmniaThemeName name) => switch (name) {
        OmniaThemeName.light => light(),
        OmniaThemeName.dim => dim(),
        OmniaThemeName.dark => dark(),
      };

  static ThemeData light() =>
      _build(OmniaPalette.defaults, Brightness.light, isDark: false);

  /// The default dark theme — a soft blue-grey, not black.
  static ThemeData dim() =>
      _build(OmniaPalette.subdued.invert(), Brightness.dark, isDark: true);

  /// True black, for OLED.
  static ThemeData dark() =>
      _build(OmniaPalette.defaults.invert(), Brightness.dark, isDark: true);

  static ThemeData _build(
    OmniaPalette palette,
    Brightness brightness, {
    required bool isDark,
  }) {
    final omnia = OmniaColors(palette: palette, isDark: isDark);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: omnia.accent,
      onPrimary: OmniaPalette.white,
      primaryContainer: palette.primary100,
      onPrimaryContainer: isDark ? palette.primary900 : palette.primary700,
      secondary: omnia.textMedium,
      onSecondary: omnia.bg,
      surface: omnia.bg,
      onSurface: omnia.text,
      surfaceContainerLowest: omnia.bg,
      surfaceContainerLow: omnia.bg25,
      surfaceContainer: omnia.bg50,
      surfaceContainerHigh: omnia.bg50,
      surfaceContainerHighest: omnia.bg100,
      onSurfaceVariant: omnia.textMedium,
      error: omnia.negativeSolid,
      onError: OmniaPalette.white,
      errorContainer: omnia.negativeSurface,
      onErrorContainer: omnia.negative,
      outline: omnia.borderHigh,
      outlineVariant: omnia.borderLow,
      shadow: OmniaPalette.black,
      scrim: OmniaPalette.black,
      inverseSurface: omnia.text,
      onInverseSurface: omnia.bg,
    );

    final text = _textTheme(omnia);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: omnia.bg,
      canvasColor: omnia.bg,
      extensions: [omnia],

      // Bluesky is a React Native app: presses are scale + opacity, never an
      // expanding ink ripple. Kill ripples globally.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      textTheme: text,
      primaryTextTheme: text,

      appBarTheme: AppBarTheme(
        backgroundColor: omnia.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: omnia.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 52,
        titleSpacing: Space.lg,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: omnia.bg,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: omnia.bg,
              ),
        titleTextStyle: text.titleMedium?.copyWith(
          fontSize: FontSizes.lg,
          fontWeight: Weights.bold,
        ),
        iconTheme: IconThemeData(color: omnia.text, size: 22),
        actionsIconTheme: IconThemeData(color: omnia.text, size: 22),
      ),

      iconTheme: IconThemeData(color: omnia.textMedium, size: 20),

      dividerTheme: DividerThemeData(
        color: omnia.borderLow,
        thickness: 1,
        space: 1,
      ),

      // Nothing in this app should render a Material Card, but if something
      // slips through it must not grow a shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        color: omnia.bg,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),

      // The bespoke `OmniaButton` is what the app uses; these keep any
      // stray Material button on-language.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: omnia.accent,
          foregroundColor: OmniaPalette.white,
          disabledBackgroundColor: omnia.accentDisabled,
          disabledForegroundColor: omnia.textInverted,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xxl,
            vertical: Space.md,
          ),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.md,
            fontWeight: Weights.medium,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: omnia.text,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: omnia.borderMedium),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.md,
            fontWeight: Weights.medium,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: omnia.link,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.md,
            fontWeight: Weights.semiBold,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: omnia.bg25,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        hintStyle: TextStyle(color: omnia.textLow, fontSize: FontSizes.md),
        labelStyle: TextStyle(color: omnia.textMedium, fontSize: FontSizes.md),
        floatingLabelStyle:
            TextStyle(color: omnia.link, fontSize: FontSizes.sm),
        helperStyle: TextStyle(color: omnia.textLow, fontSize: FontSizes.sm),
        errorStyle: TextStyle(color: omnia.negative, fontSize: FontSizes.sm),
        border: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: omnia.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: omnia.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: omnia.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: omnia.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: omnia.negative, width: 1.5),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: omnia.bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: omnia.bg,
        modalBarrierColor: omnia.scrim,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
        showDragHandle: false,
        dragHandleColor: omnia.borderHigh,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: omnia.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rXl),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: omnia.text,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: omnia.bg,
          fontSize: FontSizes.md,
          fontWeight: Weights.medium,
        ),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? OmniaPalette.white
                : omnia.bg),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? omnia.accent : omnia.bg100),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.transparent
                : omnia.borderMedium),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: omnia.accent,
        linearTrackColor: omnia.bg50,
        circularTrackColor: Colors.transparent,
        strokeWidth: 2.5,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: omnia.textMedium,
        textColor: omnia.text,
        horizontalTitleGap: Space.md,
        minVerticalPadding: Space.md,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: omnia.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(color: omnia.borderLow),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: omnia.text,
          borderRadius: Radii.rSm,
        ),
        textStyle: TextStyle(color: omnia.bg, fontSize: FontSizes.sm),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: omnia.accent,
        selectionColor: omnia.accent.withValues(alpha: 0.28),
        selectionHandleColor: omnia.accent,
      ),
    );
  }

  /// The ALF type scale, mapped onto Material's slots.
  ///
  /// Tracking is zero everywhere — ALF's `TRACKING = 0`. Balances and amounts
  /// opt into tabular figures so they don't jitter while animating.
  static TextTheme _textTheme(OmniaColors omnia) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = LineHeights.snug,
      Color? color,
      List<FontFeature>? features,
    }) =>
        TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: kTracking,
          color: color ?? omnia.text,
          fontFeatures: features,
        );

    return TextTheme(
      // Balance-scale numerals.
      displayLarge: style(FontSizes.x5l, Weights.bold,
          height: LineHeights.tight, features: kTabularFigures),
      displayMedium: style(FontSizes.x4l, Weights.bold,
          height: LineHeights.tight, features: kTabularFigures),
      displaySmall: style(FontSizes.xxxl, Weights.bold,
          height: LineHeights.tight, features: kTabularFigures),

      // Screen and section headings.
      headlineLarge:
          style(FontSizes.xxxl, Weights.bold, height: LineHeights.tight),
      headlineMedium:
          style(FontSizes.xxl, Weights.bold, height: LineHeights.tight),
      headlineSmall:
          style(FontSizes.xl, Weights.bold, height: LineHeights.snug),

      // Row titles, app-bar titles.
      titleLarge: style(FontSizes.lg, Weights.bold),
      titleMedium: style(FontSizes.md, Weights.semiBold),
      titleSmall: style(FontSizes.sm, Weights.semiBold),

      // Prose.
      bodyLarge:
          style(FontSizes.lg, Weights.normal, height: LineHeights.relaxed),
      bodyMedium:
          style(FontSizes.md, Weights.normal, height: LineHeights.relaxed),
      bodySmall: style(FontSizes.sm, Weights.normal,
          height: LineHeights.relaxed, color: omnia.textMedium),

      // Metadata and button text.
      labelLarge: style(FontSizes.md, Weights.medium),
      labelMedium: style(FontSizes.sm, Weights.medium, color: omnia.textLow),
      labelSmall: style(FontSizes.xs, Weights.medium, color: omnia.textLow),
    );
  }
}
