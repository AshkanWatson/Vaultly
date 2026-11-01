import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS system colours (Human Interface Guidelines), so Vaultly looks like
/// Apple's Passwords app on every platform, in light and dark mode.
@immutable
class VColors extends ThemeExtension<VColors> {
  const VColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.fill,
    required this.separator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.blue,
    required this.green,
    required this.red,
    required this.orange,
    required this.yellow,
    required this.teal,
    required this.indigo,
    required this.purple,
    required this.pink,
    required this.gray,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color fill;
  final Color separator;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color blue;
  final Color green;
  final Color red;
  final Color orange;
  final Color yellow;
  final Color teal;
  final Color indigo;
  final Color purple;
  final Color pink;
  final Color gray;

  static const light = VColors(
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFFFFFFF),
    fill: Color(0x1F767680),
    separator: Color(0xFFC6C6C8),
    label: Color(0xFF000000),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    blue: Color(0xFF007AFF),
    green: Color(0xFF34C759),
    red: Color(0xFFFF3B30),
    orange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    teal: Color(0xFF30B0C7),
    indigo: Color(0xFF5856D6),
    purple: Color(0xFFAF52DE),
    pink: Color(0xFFFF2D55),
    gray: Color(0xFF8E8E93),
  );

  static const dark = VColors(
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceHigh: Color(0xFF2C2C2E),
    fill: Color(0x3D767680),
    separator: Color(0xFF38383A),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0x99EBEBF5),
    tertiaryLabel: Color(0x4DEBEBF5),
    blue: Color(0xFF0A84FF),
    green: Color(0xFF30D158),
    red: Color(0xFFFF453A),
    orange: Color(0xFFFF9F0A),
    yellow: Color(0xFFFFD60A),
    teal: Color(0xFF40C8E0),
    indigo: Color(0xFF5E5CE6),
    purple: Color(0xFFBF5AF2),
    pink: Color(0xFFFF375F),
    gray: Color(0xFF8E8E93),
  );

  /// Palette for monogram icons.
  List<Color> get accents =>
      [blue, green, orange, red, teal, indigo, purple, pink, yellow];

  @override
  VColors copyWith() => this;

  @override
  VColors lerp(ThemeExtension<VColors>? other, double t) {
    if (other is! VColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return VColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      fill: l(fill, other.fill),
      separator: l(separator, other.separator),
      label: l(label, other.label),
      secondaryLabel: l(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: l(tertiaryLabel, other.tertiaryLabel),
      blue: l(blue, other.blue),
      green: l(green, other.green),
      red: l(red, other.red),
      orange: l(orange, other.orange),
      yellow: l(yellow, other.yellow),
      teal: l(teal, other.teal),
      indigo: l(indigo, other.indigo),
      purple: l(purple, other.purple),
      pink: l(pink, other.pink),
      gray: l(gray, other.gray),
    );
  }
}

extension VThemeX on BuildContext {
  VColors get colors => Theme.of(this).extension<VColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, VColors.light);
  static ThemeData dark() => _build(Brightness.dark, VColors.dark);

  static ThemeData _build(Brightness b, VColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.blue,
      brightness: b,
    ).copyWith(
      primary: c.blue,
      onPrimary: Colors.white,
      error: c.red,
      surface: c.surface,
      onSurface: c.label,
      surfaceContainerHighest: c.surfaceHigh,
      outlineVariant: c.separator,
    );

    // SF Pro-like scale (iOS Dynamic Type "Large" defaults).
    final base = (b == Brightness.light
            ? Typography.material2021().black
            : Typography.material2021().white)
        .apply(bodyColor: c.label, displayColor: c.label);
    final text = base.copyWith(
      displaySmall: base.displaySmall
          ?.copyWith(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37),
      headlineMedium: base.headlineMedium
          ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36),
      headlineSmall: base.headlineSmall
          ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35),
      titleLarge: base.titleLarge
          ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38),
      titleMedium: base.titleMedium
          ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41),
      bodyLarge: base.bodyLarge
          ?.copyWith(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.41),
      bodyMedium: base.bodyMedium
          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.24),
      bodySmall: base.bodySmall?.copyWith(
          fontSize: 13, letterSpacing: -0.08, color: c.secondaryLabel),
      labelSmall: base.labelSmall?.copyWith(
          fontSize: 12, letterSpacing: 0, color: c.secondaryLabel),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: c.fill,
      extensions: [c],
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: b,
        primaryColor: c.blue,
        scaffoldBackgroundColor: c.background,
        barBackgroundColor: c.background.withValues(alpha: 0.85),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: c.blue,
        titleTextStyle: text.titleMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: s.contains(WidgetState.selected) ? c.blue : c.gray,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 26,
              color: s.contains(WidgetState.selected) ? c.blue : c.gray,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.blue.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: c.blue),
        unselectedIconTheme: IconThemeData(color: c.gray),
        selectedLabelTextStyle: text.bodyLarge
            ?.copyWith(color: c.blue, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: text.bodyLarge?.copyWith(color: c.label),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: c.tertiaryLabel),
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.blue,
        selectionColor: c.blue.withValues(alpha: 0.3),
        selectionHandleColor: c.blue,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.green : c.fill),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.blue,
        inactiveTrackColor: c.fill,
        thumbColor: Colors.white,
        overlayShape: SliderComponentShape.noOverlay,
        trackHeight: 4,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.tertiaryLabel,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        contentTextStyle: TextStyle(color: c.label, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
