import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Linguagem visual da app: fundo neutro, cartões brancos muito arredondados,
/// tipografia forte e o verde do clube só onde há acção ou identidade.
abstract final class Tema {
  static const verde = Color(0xFF0B5D3B);
  static const verdeVivo = Color(0xFF12A15F);
  static const verdeEscuro = Color(0xFF06341F);
  static const alerta = Color(0xFFE5484D);

  static const raio = 24.0;
  static const raioPequeno = 16.0;
  static const margem = 16.0;

  /// Gradiente do topo do ecrã do sócio e do cartão.
  static const gradienteClube = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14935A), verde, verdeEscuro],
  );

  static ThemeData claro() => _tema(
    const ColorScheme(
      brightness: Brightness.light,
      primary: verde,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDF3E7),
      onPrimaryContainer: verdeEscuro,
      secondary: verdeVivo,
      onSecondary: Colors.white,
      error: alerta,
      onError: Colors.white,
      surface: Color(0xFFF4F5F7),
      onSurface: Color(0xFF16181C),
      onSurfaceVariant: Color(0xFF75777D),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFECEEF1),
      surfaceContainerHigh: Color(0xFFE6E8EC),
      surfaceContainerHighest: Color(0xFFDFE2E6),
      outline: Color(0xFFD5D8DD),
      outlineVariant: Color(0xFFE8EAEE),
    ),
  );

  static ThemeData escuro() => _tema(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF3DD68C),
      onPrimary: Color(0xFF002814),
      primaryContainer: Color(0xFF0F3D27),
      onPrimaryContainer: Color(0xFFB8F2D2),
      secondary: verdeVivo,
      onSecondary: Colors.white,
      error: Color(0xFFFF6369),
      onError: Colors.black,
      surface: Color(0xFF000000),
      onSurface: Color(0xFFF2F3F5),
      onSurfaceVariant: Color(0xFF8E9197),
      surfaceContainerLowest: Color(0xFF16181B),
      surfaceContainerLow: Color(0xFF16181B),
      surfaceContainer: Color(0xFF1F2226),
      surfaceContainerHigh: Color(0xFF272A2F),
      surfaceContainerHighest: Color(0xFF2F3338),
      outline: Color(0xFF3A3E44),
      outlineVariant: Color(0xFF26292D),
    ),
  );

  static ThemeData _tema(ColorScheme c) {
    final base = ThemeData(colorScheme: c, useMaterial3: true, fontFamily: 'Inter');
    final t = base.textTheme;
    final escuro = c.brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor: c.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: t.copyWith(
        displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2),
        headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: t.bodyMedium?.copyWith(color: c.onSurface),
        bodySmall: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: escuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: t.titleLarge?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          color: c.onSurface,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raio)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: c.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(raioPequeno), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPequeno),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPequeno),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPequeno),
          borderSide: BorderSide(color: c.error, width: 1),
        ),
        labelStyle: TextStyle(color: c.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? c.onSurface : c.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.onSurface : c.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: t.titleSmall?.copyWith(fontFamily: 'Inter', color: c.onSurface, fontWeight: FontWeight.w600),
        subtitleTextStyle: t.bodySmall?.copyWith(fontFamily: 'Inter', color: c.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raioPequeno)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
