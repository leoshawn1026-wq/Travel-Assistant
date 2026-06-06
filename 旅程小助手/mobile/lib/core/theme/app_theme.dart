import 'package:flutter/material.dart';

/// Organic anchor — earth tones, rounded corners, warm geometric sans
///
/// Palette derived from brand guidelines but pushed into Organic territory:
///   Terracotta  #C66B3D  → primary (was coral #FF7A45)
///   Sage        #8B9D83  → secondary (was mint #8DE2C4)
///   Ochre       #C08E3A  → accent  (was yellow #FFD93D)
///   Clay        #B08B6E  → text-secondary
///   Sand        #E8DCC7  → background  (was cream #FFF7F3)
///   Moss        #606C38  → success/safe
///
/// Horizon gradient: terracotta → ochre → sage
/// Signature: 24 px rounded corners on card surfaces
class AppTheme {
  // ── Organic palette ──
  static const primary     = Color(0xFFC66B3D); // terracotta
  static const primaryDark = Color(0xFFA8572F); // deeper terracotta
  static const secondary   = Color(0xFF8B9D83); // sage
  static const accent      = Color(0xFFC08E3A); // ochre
  static const clay        = Color(0xFFB08B6E); // clay — text-secondary
  static const moss        = Color(0xFF606C38); // moss
  static const sand        = Color(0xFFF2EBE0); // sand — 明亮温暖背景
  static const oat         = Color(0xFFD4B895); // oat — card surface

  // ── Functional ──
  static const textPrimary   = Color(0xFF2C2416);
  static const textSecondary = clay;
  static const textHint      = Color(0xFFC4B6A2);
  static const surface       = Colors.white;
  static const error         = Color(0xFFC66B3D);
  static const success       = moss;

  // ── Backward-compat aliases ──
  static const background = sand;
  static const divider    = Color(0xFFD6C9B8);
  static const pink       = Color(0xFFB08B6E); // clay — replaces old pink

  // ── Horizon gradient ──
  static const horizonGradient = LinearGradient(
    colors: [Color(0xFFC66B3D), Color(0xFFC08E3A), Color(0xFF8B9D83)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const horizonVertical = LinearGradient(
    colors: [Color(0xFFC66B3D), Color(0xFFC08E3A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows (soft, wide — no hard offset) ──
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF2C2416).withAlpha(18),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF2C2416).withAlpha(10),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  // ── Typography ──
  static const font = 'system';

  static const headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static const headingMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.55,
  );

  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textHint,
    letterSpacing: 0.4,
  );

  // ── Spacing ──
  static const double pagePadding = 20;
  static const double cardPadding = 18;
  static const double cardRadius = 18;

  // ── Stamp badge (for local recommendations) ──
  static const stampGradient = LinearGradient(
    colors: [Color(0xFFC66B3D), Color(0xFFA8572F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
