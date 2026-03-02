import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppTheme — single source of truth for all design tokens.
//  Add to pubspec.yaml fonts section:
//    - family: Poppins
//      fonts:
//        - asset: fonts/Poppins-Regular.ttf
//        - asset: fonts/Poppins-Medium.ttf   weight: 500
//        - asset: fonts/Poppins-SemiBold.ttf weight: 600
//        - asset: fonts/Poppins-Bold.ttf     weight: 700
//        - asset: fonts/Poppins-ExtraBold.ttf weight: 800
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Brand Colours ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7A2E1A); // rich brand brown
  static const Color primaryDark = Color(0xFF5C2010); // deeper (shadow/press)
  static const Color primaryLight = Color(0xFFEDD8CF); // tinted highlight
  static const Color background = Color(0xFFE8E0D5); // warm beige (page bg)
  static const Color surface = Color(0xFFF0EBE5); // card bg on beige
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFDDD5CC);
  static const Color textPrimary = Color(0xFF3B1A10);
  static const Color textSecondary = Color(0xFF7A6A62);
  static const Color textMuted = Color(0xFFAA9F99);
  static const Color success = Color(0xFF3D9970);
  static const Color warning = Color(0xFFE8A838);
  static const Color errorColor = Color(0xFFCC3333);

  // ── Font ─────────────────────────────────────────────────────────────────
  static const String fontFamily = 'Poppins';

  // ── Text Styles ──────────────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: primary,
    height: 1.15,
    letterSpacing: -0.5,
  );
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.1,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: primary,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.55,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.55,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textMuted,
    letterSpacing: 0.7,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    color: textMuted,
  );
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusPill = 50;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryDark.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> get inputShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Decorations ───────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration({Color? bg}) => BoxDecoration(
    color: bg ?? cardBg,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: border),
    boxShadow: cardShadow,
  );

  // ── Button Styles ─────────────────────────────────────────────────────────
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusPill),
    ),
    textStyle: buttonText,
  );

  static final ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primary,
    side: const BorderSide(color: primary, width: 1.5),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusPill),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppTheme.border);
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          Text(title, style: AppTheme.heading2),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppTheme.border)),
        ],
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  final String text;
  const AppBadge(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.label.copyWith(color: AppTheme.primary),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const StarRow({super.key, required this.rating, this.size = 16});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
          color: AppTheme.warning,
          size: size,
        ),
      ),
    );
  }
}

/// Pill primary button with drop shadow (matches login "Sign In" button)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: AppTheme.primaryButtonStyle,
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(label, style: AppTheme.buttonText),
        ),
      ),
    );
  }
}
