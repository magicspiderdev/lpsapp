import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// O tema da app, em claro e escuro (design system, `docs/ui-audit.md` §6).
///
/// Fundo neutro, blocos brancos muito arredondados, tipografia forte e o verde
/// do clube só onde há acção ou identidade. Os componentes do Material ficam
/// configurados aqui, para os ecrãs não repetirem estilos.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColorSchemes.light, AppColors.light);

  static ThemeData dark() => _build(AppColorSchemes.dark, AppColors.dark);

  /// A Comunidade: o jogo do clube tem fundo próprio, igual nos dois modos.
  static ThemeData arena() => _build(AppArena.scheme, AppArena.colors);

  static ThemeData _build(ColorScheme c, AppColors cores) {
    final texto = AppTypography.textTheme(c);
    final escuro = c.brightness == Brightness.dark;

    // Campos: fundo de superfície e contorno visível (3:1), mais forte com foco.
    OutlineInputBorder contorno(Color cor, [double largura = 1]) => OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: cor, width: largura),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: c,
      brightness: c.brightness,
      fontFamily: AppTypography.family,
      textTheme: texto,
      extensions: [cores],
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(color: c.onSurface, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: escuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: texto.titleLarge,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ).copyWith(color: c.surfaceContainerLowest),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: AppRadius.pill,
          textStyle: texto.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          shape: AppRadius.pill,
          side: BorderSide(color: c.outline),
          textStyle: texto.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          shape: AppRadius.pill,
          textStyle: texto.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(AppSpacing.minTouchTarget)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: texto.labelLarge,
          side: BorderSide(color: c.outline),
          selectedBackgroundColor: c.primaryContainer,
          selectedForegroundColor: c.onPrimaryContainer,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: AppRadius.pill,
        side: BorderSide.none,
        backgroundColor: c.surfaceContainerLowest,
        selectedColor: c.primary,
        checkmarkColor: c.onPrimary,
        labelStyle: texto.labelLarge?.copyWith(color: c.onSurface),
        secondaryLabelStyle: texto.labelLarge?.copyWith(color: c.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg + AppSpacing.xs, vertical: AppSpacing.lg),
        border: contorno(c.outline),
        enabledBorder: contorno(c.outline),
        focusedBorder: contorno(c.primary, 2),
        errorBorder: contorno(c.error),
        focusedErrorBorder: contorno(c.error, 2),
        disabledBorder: contorno(c.outlineVariant),
        labelStyle: texto.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        floatingLabelStyle: texto.bodyMedium?.copyWith(color: c.primary, fontWeight: AppTypography.semiBold),
        hintStyle: texto.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        helperStyle: texto.bodySmall,
        errorStyle: texto.bodySmall?.copyWith(color: c.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // Só ícones: com cinco separadores e a letra do sistema grande, os
        // nomes partiam-se em duas linhas. O nome continua a ser o tooltip
        // (toque longo) e o que o leitor de ecrã diz.
        height: 60,
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.onSurfaceVariant,
          ),
        ),
        // 12 px (era 11): o mínimo da app.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => texto.labelMedium?.copyWith(
            letterSpacing: 0,
            color: s.contains(WidgetState.selected) ? c.onSurface : c.onSurfaceVariant,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        iconColor: c.onSurfaceVariant,
        titleTextStyle: texto.titleSmall,
        subtitleTextStyle: texto.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: texto.headlineSmall,
        contentTextStyle: texto.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: texto.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: c.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.inverseSurface, borderRadius: AppRadius.xsAll),
        textStyle: texto.labelMedium?.copyWith(color: c.onInverseSurface, letterSpacing: 0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        extendedTextStyle: texto.labelLarge,
        shape: AppRadius.pill,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.outline,
        ),
      ),
    );
  }
}
