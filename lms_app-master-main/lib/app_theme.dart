import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4B2313); // deep brown
  static const Color primaryLight = Color(0xFF6D391E); // lighter brown
  static const Color completed = Color(0xFF2E7D5E); // muted green
  static const Color completedLight = Color(0xFF22C372); // bright green
  static const Color inProgress = Color(0xFFB05A1A); // warm orange-brown
  static const Color background = Color(0xFFF7F4F2); // warm off-white
  static const Color surface = Colors.white;
  static const Color divider = Color(0x0D000000); // black @ 5%
  static const Color textPrimary = Color(0xDD000000); // black87
  static const Color textSecondary = Color(0x8A000000); // black54
  static const Color textHint = Color(0x61000000); // black38
  static const Color placeholder = Color(0xFFEDE8E5);
  static const Color cardShadow = Color(0x0E000000); // black @ ~5.5%

  // ── Typography ────────────────────────────────────────────────────────────

  // Display — large hero numbers / headings
  static TextStyle get displayLarge => GoogleFonts.poppins(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    color: surface,
    height: 1.0,
    letterSpacing: -1.0,
  );

  // Page title (AppBar)
  static TextStyle get appBarTitle => GoogleFonts.poppins(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  // Section / screen heading
  static TextStyle get headingLarge => GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get headingMedium => GoogleFonts.poppins(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  // Card title
  static TextStyle get cardTitle => GoogleFonts.poppins(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
    letterSpacing: -0.1,
  );

  // Overline / section label (e.g. "IN PROGRESS")
  static TextStyle get overline => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textHint,
    letterSpacing: 1.6,
  );

  // Body text
  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // Label / caption
  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle get labelSmall => GoogleFonts.poppins(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: textHint,
  );

  // Stat count on secondary cards
  static TextStyle get statCount => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.0,
    letterSpacing: -0.8,
  );

  // Bottom nav labels
  static TextStyle get navLabelSelected =>
      GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600);

  static TextStyle get navLabelUnselected =>
      GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400);

  // Progress label ("Done" / "74%")
  static TextStyle get progressLabel => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  // Welcome sub-label ("Welcome back,")
  static TextStyle get welcomeSub => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textHint,
  );

  // ── Decoration helpers ────────────────────────────────────────────────────

  /// Standard white card with soft shadow
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(color: cardShadow, blurRadius: 24, offset: const Offset(0, 6)),
    ],
  );

  /// Primary (brown) hero card — e.g. enrolled count
  static BoxDecoration get primaryCardDecoration =>
      BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18));

  /// Subtle section pill (count badge on section labels)
  static BoxDecoration get sectionPillDecoration => BoxDecoration(
    color: const Color(0x0F000000),
    borderRadius: BorderRadius.circular(20),
  );

  // ── AppBar ────────────────────────────────────────────────────────────────

  static AppBar buildAppBar({
    required String title,
    List<Widget>? actions,
    bool showBack = true,
    Color foreground = primary,
  }) {
    return AppBar(
      title: Text(title, style: appBarTitle),
      centerTitle: true,
      backgroundColor: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foreground,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: divider),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  static Widget buildProgressBar(double progress, {bool isCompleted = false}) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: const Color(0x0F000000),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? completed : primary,
              ),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          isCompleted ? "Done" : "${progress.toInt()}%",
          style: progressLabel.copyWith(
            color: isCompleted ? completed : textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────

  static Widget get cardDivider =>
      Divider(height: 1, thickness: 1, color: divider);

  // ── Full MaterialTheme ────────────────────────────────────────────────────

  static ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      surface: surface,
      background: background,
    ),
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: appBarTitle,
      foregroundColor: primary,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: const Color(0xFF9E9E9E),
      elevation: 0,
      selectedLabelStyle: navLabelSelected,
      unselectedLabelStyle: navLabelUnselected,
    ),
    dividerColor: divider,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    useMaterial3: true,
  );
}
