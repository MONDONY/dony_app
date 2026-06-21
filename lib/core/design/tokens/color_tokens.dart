import 'package:flutter/material.dart';

abstract final class DonyColors {
  // ═══════════════════════════════════════════════════════════════
  // BLEU DONY — Primaire (Confiance)
  // ═══════════════════════════════════════════════════════════════
  static const blue50  = Color(0xFFEDF2FF);
  static const blue100 = Color(0xFFD6E1FF);
  static const blue200 = Color(0xFFA8BEFF);
  static const blue300 = Color(0xFF6F92FF);
  static const blue400 = Color(0xFF3D72FF);
  static const blue500 = Color(0xFF0B5FFF); // PRIMARY ★
  static const blue600 = Color(0xFF0A4DD9); // Hover
  static const blue700 = Color(0xFF083CAB); // Press/active
  static const blue800 = Color(0xFF062B7D);
  static const blue900 = Color(0xFF041D54);

  // ═══════════════════════════════════════════════════════════════
  // TERRACOTTA DONY — Accent (Chaleur africaine)
  // ═══════════════════════════════════════════════════════════════
  static const terra50  = Color(0xFFFCF0E9);
  static const terra100 = Color(0xFFF8DBC8);
  static const terra200 = Color(0xFFF2B898);
  static const terra300 = Color(0xFFEA9468);
  static const terra400 = Color(0xFFE27A4D);
  static const terra500 = Color(0xFFD96A3A); // ACCENT ★
  static const terra600 = Color(0xFFB95524);
  static const terra700 = Color(0xFF93421B);
  static const terra800 = Color(0xFF6E3114);
  static const terra900 = Color(0xFF48200D);

  // ═══════════════════════════════════════════════════════════════
  // NEUTRAL — Gris chauds (légère teinte sable)
  // ═══════════════════════════════════════════════════════════════
  static const neutral0   = Color(0xFFFFFFFF);  // Blanc pur
  static const neutral50  = Color(0xFFFAFAF8);  // BG APP ★
  static const neutral100 = Color(0xFFF2F1ED);
  static const neutral200 = Color(0xFFE8E5DF);  // Bordure default ★
  static const neutral300 = Color(0xFFD2CDC2);
  static const neutral400 = Color(0xFFA8A294);
  static const neutral500 = Color(0xFF797367);
  static const neutral600 = Color(0xFF54504A);
  static const neutral700 = Color(0xFF3A3733);
  static const neutral800 = Color(0xFF25231F);
  static const neutral900 = Color(0xFF14130F);

  // ═══════════════════════════════════════════════════════════════
  // SAND — Surface communautaire chaude
  // ═══════════════════════════════════════════════════════════════
  static const sand50  = Color(0xFFFBF8F2);
  static const sand100 = Color(0xFFF7F3ED);  // SURFACE WARM ★
  static const sand200 = Color(0xFFEDE6D8);
  static const sand300 = Color(0xFFDFD3BA);
  static const sand400 = Color(0xFFC9B894);
  static const sand500 = Color(0xFFB09A6F);

  // ═══════════════════════════════════════════════════════════════
  // INK — Texte principal
  // ═══════════════════════════════════════════════════════════════
  static const ink50  = Color(0xFFF4F6F9);
  static const ink100 = Color(0xFFE2E7EF);
  static const ink200 = Color(0xFFC0C9D8);
  static const ink300 = Color(0xFF8595AD);
  static const ink400 = Color(0xFF4A5E7C);
  static const ink500 = Color(0xFF1F3454);
  static const ink600 = Color(0xFF142845);
  static const ink700 = Color(0xFF0E1E36);
  static const ink800 = Color(0xFF0A2540); // TEXT PRIMARY ★
  static const ink900 = Color(0xFF061833);

  // ═══════════════════════════════════════════════════════════════
  // SÉMANTIQUE — États
  // ═══════════════════════════════════════════════════════════════
  static const success50  = Color(0xFFE5F4EE);
  static const success500 = Color(0xFF0E8A5F); // Vert validation ★
  static const success700 = Color(0xFF0A6446);

  static const warning50  = Color(0xFFFCF3DF);
  static const warning500 = Color(0xFFE8A23B); // Amber ★
  static const warning700 = Color(0xFFB07725);

  static const danger50  = Color(0xFFFCE8E5);
  static const danger500 = Color(0xFFD9342B); // Rouge erreur ★
  static const danger700 = Color(0xFFA81F18);

  static const info50  = Color(0xFFE5F0FA);
  static const info500 = Color(0xFF1B7BC2); // Bleu info ★
  static const info700 = Color(0xFF115687);

  static const favorite = Color(0xFFE11D48); // Cœur favori (rempli). Contour = cs.onSurfaceVariant.

  // Accent violet / teal (badges spéciaux)
  static const amberLight  = Color(0xFFFEF3C7);
  static const amberDark   = Color(0xFFB45309);
  static const violet      = Color(0xFF7C3AED);
  static const violetLight = Color(0xFFEDE7F6);
  static const purple      = Color(0xFF6A1B9A);
  static const teal        = Color(0xFF00695C);

  // Urgence départ (matching) — < 3j / 3–7j / 7–14j / 14j+
  static const urgencyRed    = Color(0xFFEF4444);
  static const urgencyOrange = Color(0xFFF97316);
  static const urgencyAmber  = Color(0xFFFBBF24);
  static const urgencyGreen  = Color(0xFF22C55E);

  // Notation (ratings)
  static const starGold = Color(0xFFF59E0B);

  // Parrainage — palette legacy conservée pour l'écran referral
  static const referralGreen       = Color(0xFF1A6B3C);
  static const referralGreenDark   = Color(0xFF134F2D);
  static const referralGreenMid    = Color(0xFF22A55C);
  static const referralGreenAccent = Color(0xFF4CAF7D);
  static const referralGreen50     = Color(0xFFE8F5EE);

  // Pro stats — dégradé dark mode carte statistiques voyageur
  static const proBg1 = Color(0xFF1A2744); // bleu nuit profond
  static const proBg2 = Color(0xFF0D1B35); // quasi-noir bleu
  static const proBg3 = Color(0xFF1A3A6B); // bleu saphir

  // KYC badges — icônes de statut sur profil utilisateur
  static const kycBadgeBlue = Color(0xFF6FA8FF);
  static const kycBadgeGold = Color(0xFFF0B829);

  // Thread status — couleurs de chips dans thread_hero_card
  static const threadStatusOpen    = Color(0xFF0E1B2E);
  static const threadStatusAmber   = Color(0xFFB5781E);
  static const threadStatusViolet  = Color(0xFF5B21B6);
  static const threadStatusGreen   = Color(0xFF15803D);
  static const threadStatusNeutral = Color(0xFF6B7280);

  // Dégradé hero (shipment_list) — fond bleu-sable/navy selon brightness
  static const heroGradientDarkA  = Color(0xFF080D18);
  static const heroGradientDarkB  = Color(0xFF0B0918);
  static const heroGradientDarkC  = Color(0xFF0E0C09);
  static const heroGradientLightB = Color(0xFFF2F0FF);

  // ═══════════════════════════════════════════════════════════════
  // RÔLES SÉMANTIQUES — Raccourcis à préférer dans les widgets
  // ═══════════════════════════════════════════════════════════════
  static const primary      = blue500;
  static const primaryHover = blue600;
  static const primaryPress = blue700;
  static const primarySoft  = blue50;

  static const accent     = terra500;
  static const accentSoft = terra50;

  static const bgApp       = neutral50;
  static const surface     = neutral0;
  static const surfaceWarm = sand100;
  static const surfaceInfo = blue50;

  static const textPrimary = ink800;
  static const textMuted   = neutral600;
  static const textSubtle  = neutral500;
  static const textOnBrand = neutral0;

  static const borderDefault = neutral200;
  static const borderStrong  = neutral300;
  static const borderFocus   = blue500;

  // ═══════════════════════════════════════════════════════════════
  // COMPAT — Anciens noms conservés pour les widgets existants
  // ignore: flutter_style_todos
  // TODO(phase-5): migrer les widgets vers les nouveaux noms
  // ═══════════════════════════════════════════════════════════════

  // green* → blue* (le vert était une erreur de couleur primaire)
  static const greenDark = blue900;
  static const green50   = blue50;
  static const green100  = blue100;
  static const green200  = blue200;
  static const green300  = blue300;
  static const green400  = blue500; // ancien primary → nouveau primary
  static const green500  = blue600;
  static const green600  = blue700;
  static const green700  = blue800;

  // grey* → neutral*
  static const white       = neutral0;
  static const bg          = neutral50;
  static const grey50      = neutral50;
  static const grey100     = neutral100;
  static const grey200     = neutral200;
  static const grey300     = neutral300;
  static const grey400     = neutral400;
  static const grey500     = neutral500;

  // semantic old names
  static const success      = success500;
  static const successLight = success50;
  static const error        = danger500;
  static const errorLight   = danger50;
  static const warning      = warning500;
  static const warningLight = warning50;
  static const info         = info500;
  static const infoLight    = info50;

  // shadow
  static const shadow     = Color(0x1A0A2540); // ink800 @ 10%
  static const scrimLight = Color(0x33000000); // black @ 20% — ombres subtiles
  static const scrimDark  = Color(0x88000000); // black @ 53% — overlay image/hero

  // ═══════════════════════════════════════════════════════════════
  // DARK MODE — Palette dérivée
  // Recalibrée pour contraste WCAG AA sur fond sombre
  // ═══════════════════════════════════════════════════════════════

  // Bleu primary recalibré (le #0B5FFF est trop saturé sur fond sombre)
  static const blueDark500 = Color(0xFF4D8AFF); // PRIMARY DARK ★
  static const blueDark600 = Color(0xFF6699FF); // Hover dark
  static const blueDark700 = Color(0xFF3D7AEF); // Press dark
  static const blueDark50  = Color(0xFF1A2B47); // PrimarySoft dark

  // Terra accent recalibré
  static const terraDark500 = Color(0xFFE8865B); // ACCENT DARK ★
  static const terraDark50  = Color(0xFF2E1F18); // Fond accent dark
  static const terraDark700 = Color(0xFFB95524);

  // Neutrals dark (chauds, cohérents avec sand)
  static const neutralDark0   = Color(0xFF0A0E14); // BG APP DARK ★
  static const neutralDark50  = Color(0xFF11161E);
  static const neutralDark100 = Color(0xFF161B23); // SURFACE DARK ★
  static const neutralDark200 = Color(0xFF222932);
  static const neutralDark300 = Color(0xFF2D333D); // BORDER DARK ★
  static const neutralDark400 = Color(0xFF7E7972); // text subtle dark
  static const neutralDark500 = Color(0xFFB5AFA5); // text muted dark
  static const neutralDark600 = Color(0xFFD8D2C7); // text high
  static const neutralDark700 = Color(0xFFF5F0E8); // TEXT PRIMARY DARK ★

  // Sand dark
  static const sandDark100 = Color(0xFF1F1A14); // SURFACE WARM DARK ★

  // États sémantiques dark
  static const successDark500 = Color(0xFF2DA677);
  static const successDark50  = Color(0xFF0F2B1F);
  static const warningDark500 = Color(0xFFF0B84A);
  static const warningDark50  = Color(0xFF2B2014);
  static const dangerDark500  = Color(0xFFEF5048);
  static const dangerDark50   = Color(0xFF2B1715);
  static const infoDark500    = Color(0xFF3FA0E5);
  static const infoDark50     = Color(0xFF0F1F2D);

  static const shadowDark = Color(0x66000000); // black @ 40%
}

extension DonyStatusColors on ColorScheme {
  Color get success => brightness == Brightness.light
      ? DonyColors.success500
      : DonyColors.successDark500;

  Color get warning => brightness == Brightness.light
      ? DonyColors.warning500
      : DonyColors.warningDark500;

  Color get info => brightness == Brightness.light
      ? DonyColors.info500
      : DonyColors.infoDark500;

  Color get successLight => brightness == Brightness.light
      ? DonyColors.success50
      : DonyColors.successDark50;

  Color get warningLight => brightness == Brightness.light
      ? DonyColors.warning50
      : DonyColors.warningDark50;

  Color get infoLight => brightness == Brightness.light
      ? DonyColors.info50
      : DonyColors.infoDark50;

  Color get errorLight => brightness == Brightness.light
      ? DonyColors.danger50
      : DonyColors.dangerDark50;

  Color get surfaceWarm => brightness == Brightness.light
      ? DonyColors.sand100
      : DonyColors.sandDark100;
}
