/// Design tokens transcribed from Bluesky's ALF design system
/// (`@bsky.app/alf@0.1.15` — `src/palette.ts`, `src/tokens.ts`).
///
/// See `docs/DESIGN.md` for the provenance of every number in this file.
library;

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Scales
// ---------------------------------------------------------------------------

/// Spacing scale. ALF `space`.
class Space {
  Space._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double x4l = 32;
  static const double x5l = 40;
}

/// Corner radii. ALF `borderRadius`.
///
/// [full] is the pill radius used by every button; [sheet] is the 20pt top
/// corner Bluesky's native bottom sheet uses.
class Radii {
  Radii._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;

  /// Top corners of a bottom sheet (`cornerRadius={20}`).
  static const double sheet = 20;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rFull = BorderRadius.all(Radius.circular(full));

  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Type scale. ALF `fontSize` — a 1.125 modular scale off a 15pt base.
/// The fractional values are deliberate; rounding them changes the feel.
class FontSizes {
  FontSizes._();

  static const double xxs = 9.4;
  static const double xs = 11.3;
  static const double sm = 13.1;
  static const double md = 15;
  static const double lg = 16.9;
  static const double xl = 18.8;
  static const double xxl = 20.6;
  static const double xxxl = 24.3;
  static const double x4l = 30;
  static const double x5l = 37.5;
}

/// ALF `lineHeight`, as Flutter `height` multipliers.
class LineHeights {
  LineHeights._();

  static const double tight = 1.15;
  static const double snug = 1.3;
  static const double relaxed = 1.5;
}

/// ALF `fontWeight`. Note there is no 800 — the old theme's ExtraBold
/// headings are not part of this language.
class Weights {
  Weights._();

  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

/// ALF `TRACKING = 0`. Headings are *not* tightened.
const double kTracking = 0;

/// Tabular figures keep balances from reflowing as they animate.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// One ALF palette: four ramps plus a handful of fixed brand colours.
///
/// The dark palettes are produced by [invert], which mirrors ALF's
/// `invertPalette` — reading each ramp backwards. This is why light and dark
/// never drift apart.
@immutable
class OmniaPalette {
  const OmniaPalette({
    required this.contrast,
    required this.primary,
    required this.positive,
    required this.negative,
    required this.pink,
    required this.yellow,
  });

  /// Neutral ramp, 15 stops: 0, 25, 50, 100, 200 … 900, 950, 975, 1000.
  final List<Color> contrast;

  /// Accent / positive / negative ramps, 13 stops:
  /// 25, 50, 100, 200 … 900, 950, 975.
  final List<Color> primary;
  final List<Color> positive;
  final List<Color> negative;

  final Color pink;
  final Color yellow;

  // -- contrast accessors (index into the 15-stop ramp) --
  Color get contrast0 => contrast[0];
  Color get contrast25 => contrast[1];
  Color get contrast50 => contrast[2];
  Color get contrast100 => contrast[3];
  Color get contrast200 => contrast[4];
  Color get contrast300 => contrast[5];
  Color get contrast400 => contrast[6];
  Color get contrast500 => contrast[7];
  Color get contrast600 => contrast[8];
  Color get contrast700 => contrast[9];
  Color get contrast800 => contrast[10];
  Color get contrast900 => contrast[11];
  Color get contrast950 => contrast[12];
  Color get contrast975 => contrast[13];
  Color get contrast1000 => contrast[14];

  // -- 13-stop ramp accessors --
  Color get primary25 => primary[0];
  Color get primary50 => primary[1];
  Color get primary100 => primary[2];
  Color get primary200 => primary[3];
  Color get primary300 => primary[4];
  Color get primary400 => primary[5];
  Color get primary500 => primary[6];
  Color get primary600 => primary[7];
  Color get primary700 => primary[8];
  Color get primary800 => primary[9];
  Color get primary900 => primary[10];
  Color get primary950 => primary[11];
  Color get primary975 => primary[12];

  Color get positive25 => positive[0];
  Color get positive50 => positive[1];
  Color get positive100 => positive[2];
  Color get positive200 => positive[3];
  Color get positive300 => positive[4];
  Color get positive400 => positive[5];
  Color get positive500 => positive[6];
  Color get positive600 => positive[7];
  Color get positive700 => positive[8];

  Color get negative25 => negative[0];
  Color get negative50 => negative[1];
  Color get negative100 => negative[2];
  Color get negative200 => negative[3];
  Color get negative300 => negative[4];
  Color get negative400 => negative[5];
  Color get negative500 => negative[6];
  Color get negative600 => negative[7];
  Color get negative700 => negative[8];

  /// ALF `invertPalette`: the contrast ramp is reversed end-to-end, and the
  /// three semantic ramps are reversed around their fixed 500 midpoint.
  OmniaPalette invert() => OmniaPalette(
        contrast: contrast.reversed.toList(growable: false),
        primary: primary.reversed.toList(growable: false),
        positive: positive.reversed.toList(growable: false),
        negative: negative.reversed.toList(growable: false),
        pink: pink,
        yellow: yellow,
      );

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// ALF `DEFAULT_PALETTE`.
  static const OmniaPalette defaults = OmniaPalette(
    pink: Color(0xFFEC4899),
    yellow: Color(0xFFFFC404),
    contrast: [
      Color(0xFFFFFFFF), // 0
      Color(0xFFF9FAFB), // 25
      Color(0xFFEFF2F6), // 50
      Color(0xFFDCE2EA), // 100
      Color(0xFFC0CAD8), // 200
      Color(0xFFA5B2C5), // 300
      Color(0xFF8798B0), // 400
      Color(0xFF667B99), // 500
      Color(0xFF526580), // 600
      Color(0xFF405168), // 700
      Color(0xFF313F54), // 800
      Color(0xFF232E3E), // 900
      Color(0xFF19222E), // 950
      Color(0xFF111822), // 975
      Color(0xFF000000), // 1000
    ],
    primary: [
      Color(0xFFF5F9FF), // 25
      Color(0xFFE5F0FF), // 50
      Color(0xFFCCE1FF), // 100
      Color(0xFFA8CCFF), // 200
      Color(0xFF75AFFF), // 300
      Color(0xFF4291FF), // 400
      Color(0xFF006AFF), // 500
      Color(0xFF0059D6), // 600
      Color(0xFF0048AD), // 700
      Color(0xFF00398A), // 800
      Color(0xFF002861), // 900
      Color(0xFF001E47), // 950
      Color(0xFF001533), // 975
    ],
    positive: [
      Color(0xFFECFEF5),
      Color(0xFFD3FDE8),
      Color(0xFFA3FACF),
      Color(0xFF6AF6B0),
      Color(0xFF2CF28F),
      Color(0xFF0DD370),
      Color(0xFF09B35E),
      Color(0xFF04904A),
      Color(0xFF036D38),
      Color(0xFF04522B),
      Color(0xFF033F21),
      Color(0xFF032A17),
      Color(0xFF021D0F),
    ],
    negative: [
      Color(0xFFFFF5F7),
      Color(0xFFFEE7EC),
      Color(0xFFFDD3DD),
      Color(0xFFFBBBCA),
      Color(0xFFF891A9),
      Color(0xFFF65A7F),
      Color(0xFFE91646),
      Color(0xFFCA123D),
      Color(0xFFA71134),
      Color(0xFF7F0B26),
      Color(0xFF5F071C),
      Color(0xFF430413),
      Color(0xFF30030D),
    ],
  );

  /// ALF `DEFAULT_SUBDUED_PALETTE` — the source of the "dim" theme.
  static const OmniaPalette subdued = OmniaPalette(
    pink: Color(0xFFEC4899),
    yellow: Color(0xFFFFC404),
    contrast: [
      Color(0xFFFFFFFF), // 0
      Color(0xFFF9FAFB), // 25
      Color(0xFFF2F4F8), // 50
      Color(0xFFE2E7EE), // 100
      Color(0xFFC3CDDA), // 200
      Color(0xFFABB8C9), // 300
      Color(0xFF8D9DB4), // 400
      Color(0xFF6F839F), // 500
      Color(0xFF586C89), // 600
      Color(0xFF485B75), // 700
      Color(0xFF394960), // 800
      Color(0xFF2C3A4E), // 900
      Color(0xFF222E3F), // 950
      Color(0xFF1C2736), // 975
      Color(0xFF151D28), // 1000
    ],
    primary: [
      Color(0xFFF5F9FF),
      Color(0xFFEBF3FF),
      Color(0xFFD6E7FF),
      Color(0xFFADCFFF),
      Color(0xFF80B5FF),
      Color(0xFF4D97FF),
      Color(0xFF0F73FF),
      Color(0xFF0661E0),
      Color(0xFF0A52B8),
      Color(0xFF0E4490),
      Color(0xFF123464),
      Color(0xFF122949),
      Color(0xFF122136),
    ],
    positive: [
      Color(0xFFECFEF5),
      Color(0xFFD8FDEB),
      Color(0xFFA8FAD1),
      Color(0xFF6FF6B3),
      Color(0xFF31F291),
      Color(0xFF0EDD75),
      Color(0xFF0AC266),
      Color(0xFF049F52),
      Color(0xFF038142),
      Color(0xFF056636),
      Color(0xFF04522B),
      Color(0xFF053D21),
      Color(0xFF052917),
    ],
    negative: [
      Color(0xFFFFF5F7),
      Color(0xFFFEEBEF),
      Color(0xFFFDD8E1),
      Color(0xFFFCC0CE),
      Color(0xFFF99AB0),
      Color(0xFFF76486),
      Color(0xFFEB2452),
      Color(0xFFD81341),
      Color(0xFFBA1239),
      Color(0xFF910D2C),
      Color(0xFF6F0B22),
      Color(0xFF500B1C),
      Color(0xFF3E0915),
    ],
  );
}

/// Which of the three themes is active. Mirrors Bluesky's Light / Dim / Dark.
enum OmniaThemeName { light, dim, dark }

extension OmniaThemeNameX on OmniaThemeName {
  String get label => switch (this) {
        OmniaThemeName.light => 'Light',
        OmniaThemeName.dim => 'Dim',
        OmniaThemeName.dark => 'Dark',
      };

  String get wire => name;

  bool get isDark => this != OmniaThemeName.light;

  static OmniaThemeName fromWire(String? value) => switch (value) {
        'light' => OmniaThemeName.light,
        'dark' => OmniaThemeName.dark,
        'dim' => OmniaThemeName.dim,
        _ => OmniaThemeName.dim,
      };
}
