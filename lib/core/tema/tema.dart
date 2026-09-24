import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Nomes antigos do tema, mantidos enquanto os ecrãs não passam para o design
/// system (`lib/core/theme/`). Já não têm valores próprios: lêem os tokens.
///
/// Código novo usa [AppTheme], [AppColors], [AppSpacing] e [AppRadius].
abstract final class Tema {
  static const verde = AppPalette.green;
  static const verdeVivo = AppPalette.greenBright;
  static const verdeEscuro = AppPalette.greenDark;

  /// Só como cor fixa (o ponto de "novo"); em código novo, `AppColors.of(context).badge`.
  static const alerta = AppPalette.errorLight;

  static const raio = AppRadius.lg;
  static const raioPequeno = AppRadius.md;
  static const margem = AppSpacing.screen;

  static const gradienteClube = AppColors.clubGradient;

  static ThemeData claro() => AppTheme.light();
  static ThemeData escuro() => AppTheme.dark();
}
