import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Design tokens for the SDK's in-chat secondary screens (media, info pages,
/// pickers, search, wallpaper…).
///
/// Tokens are only the **default** look. Any per-screen theme the host passes
/// (`chatPageTheme.mediaTheme`, `.groupInfoTheme`, `chatTheme.profileTheme`…)
/// still wins verbatim.
///
/// - Neutrals are fixed light/dark palettes (not [IsmChatThemeData.backgroundColor],
///   which the SDK always fills, so a host value can't be told from the default).
/// - [accent] follows the host's [IsmChatThemeData.primaryColor], nudged for
///   contrast against [surface] so a dark brand colour stays readable in dark mode.
/// - Text styles carry [IsmChatConfig.fontFamily] and are built fresh (not copied
///   from the lazily captured [IsmChatStyles] statics).
@immutable
class IsmChatDesignTokens {
  const IsmChatDesignTokens._({
    required this.brightness,
    required this.accent,
    required this.fontFamily,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.danger,
    required this.segmentTrack,
    required this.segmentThumb,
  });

  /// Tokens for the brightness [IsmChatThemeResolver.brightness] picks for [context].
  factory IsmChatDesignTokens.of(BuildContext context) =>
      IsmChatDesignTokens.forBrightness(
        IsmChatThemeResolver.brightness(context),
      );

  /// Tokens without a [BuildContext] (theme `light()` / `dark()` factories).
  ///
  /// [accent] defaults to the active [IsmChatConfig.chatTheme] primary colour,
  /// [fontFamily] to [IsmChatConfig.fontFamily].
  factory IsmChatDesignTokens.forBrightness(
    Brightness brightness, {
    Color? accent,
    String? fontFamily,
  }) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? _darkSurface : _lightSurface;
    final baseAccent = accent ??
        _safePrimaryColor() ??
        (isDark
            ? IsmChatColors.primaryColorDark
            : IsmChatColors.primaryColorLight);
    return IsmChatDesignTokens._(
      brightness: brightness,
      accent: ensureContrast(baseAccent, surface, minRatio: 3),
      fontFamily: fontFamily ?? IsmChatConfig.fontFamily,
      canvas: isDark ? const Color(0xFF0B0B0C) : const Color(0xFFF2F2F7),
      surface: surface,
      surfaceMuted: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4F4F6),
      textPrimary: isDark ? const Color(0xFFF2F2F5) : const Color(0xFF111114),
      textSecondary: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B6B73),
      textTertiary: isDark ? const Color(0xFF6E6E76) : const Color(0xFF9A9AA2),
      hairline: isDark ? const Color(0xFF2E2E33) : const Color(0xFFE3E3E8),
      danger: isDark ? const Color(0xFFFF6369) : const Color(0xFFE5484D),
      segmentTrack: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE4E4E9),
      segmentThumb: isDark ? const Color(0xFF636366) : const Color(0xFFFFFFFF),
    );
  }

  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _darkSurface = Color(0xFF1C1C1E);

  /// Card corner radius.
  static const double cardRadius = 14;

  /// Thumbnail / small tile corner radius.
  static const double thumbRadius = 8;

  /// Minimum row height for text-only rows.
  static const double rowHeight = 52;

  /// Minimum row height for rows with a 40px avatar.
  static const double avatarRowHeight = 60;

  /// Horizontal page gutter.
  static const double gutter = 16;

  /// Leading icon box size in settings rows.
  static const double iconBoxSize = 30;

  /// Legacy always-black media viewer fill. SDK defaults now use the chat
  /// screen background via [IsmChatMediaTheme.chatScreenBackground]; keep this
  /// for hosts that still opt into a cinema-style black preview.
  static const Color viewerBackground = Color(0xFF000000);

  /// Icons / text over [viewerBackground] (cinema-style black preview).
  static const Color viewerForeground = Color(0xFFFFFFFF);

  final Brightness brightness;
  final String? fontFamily;

  /// Host brand colour, contrast-adjusted against [surface].
  final Color accent;

  /// Page background behind cards.
  final Color canvas;

  /// Card / sheet background.
  final Color surface;

  /// Placeholder tiles, input fills, muted chips.
  final Color surfaceMuted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Dividers and outlines.
  final Color hairline;

  /// Destructive actions (block, delete, exit).
  final Color danger;

  /// Segmented control track / selected thumb.
  final Color segmentTrack;
  final Color segmentThumb;

  bool get isDark => brightness == Brightness.dark;

  /// Tinted background for accent icons and badges.
  Color get accentSoft => accent.withValues(alpha: isDark ? .22 : .12);

  /// Tinted background for destructive icons.
  Color get dangerSoft => danger.withValues(alpha: isDark ? .22 : .12);

  /// Text / icon colour drawn on top of [accent].
  Color get onAccent => foregroundFor(accent);

  // ---------------------------------------------------------------------------
  // Type scale
  // ---------------------------------------------------------------------------

  TextStyle _text(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: _sp(size),
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Profile / group name under the avatar.
  TextStyle get headline =>
      _text(22, FontWeight.w700, textPrimary, height: 1.2, letterSpacing: -.2);

  /// App bar titles, sheet titles, empty-state titles.
  TextStyle get title =>
      _text(17, FontWeight.w600, textPrimary, height: 1.25, letterSpacing: -.1);

  /// Row titles.
  TextStyle get body => _text(16, FontWeight.w400, textPrimary, height: 1.3);

  /// Emphasised row titles (names, document names).
  TextStyle get bodyStrong =>
      _text(16, FontWeight.w500, textPrimary, height: 1.3);

  /// Compact emphasised rows (document names, segmented labels).
  TextStyle get callout => _text(15, FontWeight.w500, textPrimary, height: 1.3);

  /// Secondary line under a headline.
  TextStyle get subhead =>
      _text(15, FontWeight.w400, textSecondary, height: 1.3);

  /// Row subtitles and meta.
  TextStyle get footnote =>
      _text(13, FontWeight.w400, textSecondary, height: 1.3);

  /// Section headers — render the text upper-cased.
  TextStyle get caption =>
      _text(12, FontWeight.w600, textSecondary, letterSpacing: .6);

  /// Timestamps, badges.
  TextStyle get micro => _text(11, FontWeight.w500, textTertiary);

  /// Text on [accent] buttons.
  TextStyle get button => _text(15, FontWeight.w600, onAccent);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Black or white, whichever reads better on [background].
  static Color foregroundFor(Color background) =>
      background.computeLuminance() > .5
          ? const Color(0xFF111114)
          : const Color(0xFFFFFFFF);

  /// WCAG contrast ratio between two opaque colours (1–21).
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + .05) / (lo + .05);
  }

  /// Lightens (on dark [background]) or darkens (on light) [color] in HSL
  /// until it reaches [minRatio] against [background]. Hue and saturation are kept.
  static Color ensureContrast(
    Color color,
    Color background, {
    double minRatio = 3,
  }) {
    if (contrastRatio(color, background) >= minRatio) return color;
    final lighten = background.computeLuminance() < .5;
    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 20; i++) {
      final next = (hsl.lightness + (lighten ? .04 : -.04)).clamp(0.0, 1.0);
      hsl = hsl.withLightness(next);
      final candidate = hsl.toColor();
      if (contrastRatio(candidate, background) >= minRatio ||
          next == 0 ||
          next == 1) {
        return candidate;
      }
    }
    return hsl.toColor();
  }

  static Color? _safePrimaryColor() {
    try {
      return IsmChatConfig.chatTheme.primaryColor;
    } catch (_) {
      return null;
    }
  }

  /// [ScreenUtil] font scaling like the rest of the SDK; plain value when
  /// ScreenUtil isn't initialised (pure unit tests).
  static double _sp(double value) {
    try {
      return value.sp;
    } catch (_) {
      return value;
    }
  }
}
