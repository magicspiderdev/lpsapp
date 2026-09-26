import 'package:flutter/material.dart';

/// Cores da app (design system, `docs/ui-audit.md` §6.1).
///
/// Três camadas:
/// - **primitivas** ([AppPalette]): os valores, com nome e sem papel;
/// - **esquema** ([AppColorSchemes]): os papéis do Material 3 em claro e escuro;
/// - **extensão** ([AppColors]): o que o Material não tem — estados, marca, QR.
///
/// Os ecrãs só usam as duas últimas, pelo `Theme`. Os contrastes indicados
/// foram calculados (WCAG 2.x) e o mínimo para texto é 4,5:1.
abstract final class AppPalette {
  // Marca: o verde do clube.
  static const green = Color(0xFF0B5D3B);
  static const greenBright = Color(0xFF12A15F);
  static const greenDark = Color(0xFF06341F);
  static const greenGradientStart = Color(0xFF0F7A4A);
  static const greenLight = Color(0xFF3DD68C);
  static const greenContainer = Color(0xFFDDF3E7);
  static const greenContainerDark = Color(0xFF0F3D27);
  static const onGreenContainerDark = Color(0xFFB8F2D2);
  static const onGreenLight = Color(0xFF002814);

  // Neutros claros.
  static const grey50 = Color(0xFFF4F5F7);
  static const grey100 = Color(0xFFECEEF1);
  static const grey150 = Color(0xFFE8EAEE);
  static const grey200 = Color(0xFFE6E8EC);
  static const grey250 = Color(0xFFDFE2E6);
  static const grey500 = Color(0xFF84878D);
  static const grey600 = Color(0xFF62656B);
  static const grey900 = Color(0xFF16181C);

  // Neutros escuros.
  static const ink950 = Color(0xFF000000);
  static const ink900 = Color(0xFF16181B);
  static const ink850 = Color(0xFF1F2226);
  static const ink800 = Color(0xFF272A2F);
  static const ink750 = Color(0xFF2F3338);
  static const ink700 = Color(0xFF26292D);
  static const ink500 = Color(0xFF6B6F76);
  static const ink400 = Color(0xFF8E9197);
  static const ink50 = Color(0xFFF2F3F5);

  // Estados, versão clara (texto sobre branco e sobre o fundo de estado).
  static const successLight = Color(0xFF0F7A45); // 5,40:1 em branco · 4,56:1 no fundo
  static const successContainerLight = Color(0xFFE2EFE9);
  static const warningLight = Color(0xFF8F5B00); // 5,73:1 · 4,84:1
  static const warningContainerLight = Color(0xFFF2EBE0);
  static const errorLight = Color(0xFFC4323A); // 5,43:1 · 4,52:1
  static const errorContainerLight = Color(0xFFF8E6E7);
  static const infoLight = Color(0xFF1F5FBF); // 5,12:1 no fundo
  static const infoContainerLight = Color(0xFFE4ECF7);
  static const neutralContainerLight = Color(0xFFECEDED); // grey600: 4,98:1

  // Estados, versão escura (sobre `ink900` e sobre o fundo de estado).
  static const successDark = greenLight; // 6,93:1 no fundo
  static const successContainerDark = Color(0xFF1C362D);
  static const warningDark = Color(0xFFFFB224); // 7,09:1
  static const warningContainerDark = Color(0xFF3B311C);
  static const errorDark = Color(0xFFFF6369); // 4,93:1
  static const errorContainerDark = Color(0xFF3B2427);
  static const infoDark = Color(0xFF7AB0FF); // 6,01:1
  static const infoContainerDark = Color(0xFF26303F);
  static const neutralContainerDark = ink850; // ink400: 5,05:1

  // Arena: a Comunidade (palpites, classificação, passatempos) tem fundo
  // próprio, o mesmo nos dois modos — o relvado à noite, não o preto. O ouro
  // é só para o que se ganha: pontos, o 1.º lugar, prémios.
  static const arenaFundo = Color(0xFF041A10);
  static const arenaPainel = Color(0xFF0A2819);
  static const arenaPainelAlto = Color(0xFF10382A);
  static const arenaPainelTopo = Color(0xFF174634);
  static const arenaLinha = Color(0xFF1D4A36);
  static const arenaContorno = Color(0xFF5E8A74); // 3,9:1 no painel
  static const arenaTexto = Color(0xFFECF7F0);
  static const arenaSuave = Color(0xFF9FBDAE); // 7,7:1 no painel
  static const arenaVerde = Color(0xFF0F4A30);
  static const ouro = Color(0xFFFFD400); // o amarelo do clube (LPS Web)
  static const onOuro = Color(0xFF2A2200);
  static const prata = Color(0xFFC7D2CE);
  static const bronze = Color(0xFFD9905A);

  /// Módulos do QR: escuros sobre branco nos dois modos — um QR invertido não
  /// lê em todos os leitores da portaria.
  static const qrForeground = Color(0xFF0B0D10);
  static const qrBackground = Color(0xFFFFFFFF);
}

/// Os esquemas do Material 3.
abstract final class AppColorSchemes {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.green, // 7,28:1 no fundo
    onPrimary: Colors.white,
    primaryContainer: AppPalette.greenContainer,
    onPrimaryContainer: AppPalette.greenDark,
    secondary: AppPalette.greenBright,
    onSecondary: Colors.white,
    error: AppPalette.errorLight,
    onError: Colors.white,
    errorContainer: AppPalette.errorContainerLight,
    onErrorContainer: AppPalette.errorLight,
    surface: AppPalette.grey50,
    onSurface: AppPalette.grey900,
    // Era #75777D (4,10:1 no fundo); todo o texto secundário passa o AA.
    onSurfaceVariant: AppPalette.grey600, // 5,36:1 no fundo · 5,84:1 em branco
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: AppPalette.grey100,
    surfaceContainerHigh: AppPalette.grey200,
    surfaceContainerHighest: AppPalette.grey250,
    // Limite dos componentes (campos): era #D5D8DD, invisível. 3,30:1 no fundo.
    outline: AppPalette.grey500,
    outlineVariant: AppPalette.grey150,
    inverseSurface: Color(0xFF2A2D32),
    onInverseSurface: AppPalette.ink50,
    inversePrimary: AppPalette.greenLight,
    shadow: AppPalette.greenDark,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.greenLight, // 11,2:1 no fundo
    onPrimary: AppPalette.onGreenLight,
    primaryContainer: AppPalette.greenContainerDark,
    onPrimaryContainer: AppPalette.onGreenContainerDark,
    secondary: AppPalette.greenBright,
    onSecondary: Colors.white,
    error: AppPalette.errorDark,
    onError: Colors.black,
    errorContainer: AppPalette.errorContainerDark,
    onErrorContainer: AppPalette.errorDark,
    surface: AppPalette.ink950,
    onSurface: AppPalette.ink50,
    onSurfaceVariant: AppPalette.ink400, // 6,65:1 no fundo · 5,63:1 nos blocos
    surfaceContainerLowest: AppPalette.ink900,
    surfaceContainerLow: AppPalette.ink900,
    surfaceContainer: AppPalette.ink850,
    surfaceContainerHigh: AppPalette.ink800,
    surfaceContainerHighest: AppPalette.ink750,
    outline: AppPalette.ink500, // 3,52:1 nos blocos
    outlineVariant: AppPalette.ink700,
    inverseSurface: Color(0xFFE6E8EC),
    onInverseSurface: AppPalette.grey900,
    inversePrimary: AppPalette.green,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );
}

/// A Arena da Comunidade: escura nos dois modos (ver [AppPalette.arenaFundo]).
abstract final class AppArena {
  static const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.greenLight,
    onPrimary: AppPalette.onGreenLight,
    primaryContainer: AppPalette.arenaVerde,
    onPrimaryContainer: AppPalette.onGreenContainerDark,
    secondary: AppPalette.greenBright,
    onSecondary: Colors.white,
    tertiary: AppPalette.ouro,
    onTertiary: AppPalette.onOuro,
    error: AppPalette.errorDark,
    onError: Colors.black,
    errorContainer: AppPalette.errorContainerDark,
    onErrorContainer: AppPalette.errorDark,
    surface: AppPalette.arenaFundo,
    onSurface: AppPalette.arenaTexto,
    onSurfaceVariant: AppPalette.arenaSuave,
    surfaceContainerLowest: AppPalette.arenaPainel,
    surfaceContainerLow: AppPalette.arenaPainel,
    surfaceContainer: AppPalette.arenaPainelAlto,
    surfaceContainerHigh: AppPalette.arenaPainelAlto,
    surfaceContainerHighest: AppPalette.arenaPainelTopo,
    outline: AppPalette.arenaContorno,
    outlineVariant: AppPalette.arenaLinha,
    inverseSurface: AppPalette.arenaTexto,
    onInverseSurface: AppPalette.arenaFundo,
    inversePrimary: AppPalette.green,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const colors = AppColors(
    success: StatusColor(AppPalette.successDark, AppPalette.successContainerDark),
    warning: StatusColor(AppPalette.warningDark, AppPalette.warningContainerDark),
    error: StatusColor(AppPalette.errorDark, AppPalette.errorContainerDark),
    info: StatusColor(AppPalette.infoDark, AppPalette.infoContainerDark),
    neutral: StatusColor(AppPalette.arenaSuave, AppPalette.arenaPainelAlto),
    brandGradient: AppColors.clubGradient,
    onBrand: Colors.white,
    onBrandMuted: Color(0xE6FFFFFF),
    brandSurface: Color(0x29FFFFFF),
    badge: AppPalette.errorDark,
  );
}

/// Um estado com a cor de texto/ícone e o fundo onde ela se lê.
@immutable
class StatusColor {
  const StatusColor(this.foreground, this.container);

  /// Texto e ícone. Cumpre 4,5:1 sobre [container] e sobre a superfície.
  final Color foreground;

  /// Fundo de etiquetas, pastilhas e caixas de aviso. Opaco: o contraste não
  /// depende do que está por baixo.
  final Color container;

  static StatusColor lerp(StatusColor a, StatusColor b, double t) =>
      StatusColor(Color.lerp(a.foreground, b.foreground, t)!, Color.lerp(a.container, b.container, t)!);
}

/// O que o [ColorScheme] não tem: estados, marca e QR.
///
/// ```dart
/// final cores = AppColors.of(context);
/// Text('Pago', style: TextStyle(color: cores.success.foreground));
/// ```
///
/// Um vocabulário para os estados de dinheiro (resolve a mistura de
/// "Em dívida"/"Por pagar" e vermelho/âmbar):
/// - [error] — **Em dívida**: há um valor devido;
/// - [warning] — **A aguardar**: pagamento iniciado, ainda não confirmado;
/// - [success] — **Pago**;
/// - [neutral] — Por vencer, Isento, Previsto, Cancelado;
/// - [info] — avisos sem gravidade (informação desactualizada, dicas).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
    required this.brandGradient,
    required this.onBrand,
    required this.onBrandMuted,
    required this.brandSurface,
    required this.badge,
  });

  final StatusColor success, warning, error, info, neutral;

  /// Só nos momentos de identidade: cabeçalho do sócio, cartão, bilhetes,
  /// destaque sem capa. Nunca como fundo de interface corrente.
  final LinearGradient brandGradient;

  /// Texto principal sobre [brandGradient] (5,38:1 no ponto mais claro).
  final Color onBrand;

  /// Texto secundário sobre [brandGradient]: branco a 90 %, o mínimo que passa
  /// o AA no ponto mais claro (4,69:1). Não usar opacidades mais baixas.
  final Color onBrandMuted;

  /// Botões e pílulas de vidro sobre [brandGradient] (decorativo).
  final Color brandSurface;

  /// Ponto de "novo" (sino, chat, notificações). Nunca sozinho: acompanhar de
  /// texto ou de `Semantics`.
  final Color badge;

  Color get qrForeground => AppPalette.qrForeground;
  Color get qrBackground => AppPalette.qrBackground;

  static const clubGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    // O início era #14935A (branco a 3,92:1); escureceu para o texto passar.
    colors: [AppPalette.greenGradientStart, AppPalette.green, AppPalette.greenDark],
  );

  static const light = AppColors(
    success: StatusColor(AppPalette.successLight, AppPalette.successContainerLight),
    warning: StatusColor(AppPalette.warningLight, AppPalette.warningContainerLight),
    error: StatusColor(AppPalette.errorLight, AppPalette.errorContainerLight),
    info: StatusColor(AppPalette.infoLight, AppPalette.infoContainerLight),
    neutral: StatusColor(AppPalette.grey600, AppPalette.neutralContainerLight),
    brandGradient: clubGradient,
    onBrand: Colors.white,
    onBrandMuted: Color(0xE6FFFFFF),
    brandSurface: Color(0x29FFFFFF),
    badge: AppPalette.errorLight,
  );

  static const dark = AppColors(
    success: StatusColor(AppPalette.successDark, AppPalette.successContainerDark),
    warning: StatusColor(AppPalette.warningDark, AppPalette.warningContainerDark),
    error: StatusColor(AppPalette.errorDark, AppPalette.errorContainerDark),
    info: StatusColor(AppPalette.infoDark, AppPalette.infoContainerDark),
    neutral: StatusColor(AppPalette.ink400, AppPalette.neutralContainerDark),
    brandGradient: clubGradient,
    onBrand: Colors.white,
    onBrandMuted: Color(0xE6FFFFFF),
    brandSurface: Color(0x29FFFFFF),
    badge: AppPalette.errorDark,
  );

  /// As cores do tema activo. Falha cedo se o tema não as registou.
  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    StatusColor? success,
    StatusColor? warning,
    StatusColor? error,
    StatusColor? info,
    StatusColor? neutral,
    LinearGradient? brandGradient,
    Color? onBrand,
    Color? onBrandMuted,
    Color? brandSurface,
    Color? badge,
  }) => AppColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    info: info ?? this.info,
    neutral: neutral ?? this.neutral,
    brandGradient: brandGradient ?? this.brandGradient,
    onBrand: onBrand ?? this.onBrand,
    onBrandMuted: onBrandMuted ?? this.onBrandMuted,
    brandSurface: brandSurface ?? this.brandSurface,
    badge: badge ?? this.badge,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: StatusColor.lerp(success, other.success, t),
      warning: StatusColor.lerp(warning, other.warning, t),
      error: StatusColor.lerp(error, other.error, t),
      info: StatusColor.lerp(info, other.info, t),
      neutral: StatusColor.lerp(neutral, other.neutral, t),
      brandGradient: LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      onBrandMuted: Color.lerp(onBrandMuted, other.onBrandMuted, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
    );
  }
}
