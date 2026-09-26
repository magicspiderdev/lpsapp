import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/theme/app_colors.dart';
import 'package:lpsapp/core/theme/app_theme.dart';

double contraste(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Cor com alfa já pousada no fundo, como o olho a vê.
Color sobre(Color frente, Color fundo) => Color.alphaBlend(frente, fundo);

void main() {
  for (final (nome, tema) in [('claro', AppTheme.light()), ('escuro', AppTheme.dark()), ('arena', AppTheme.arena())]) {
    group('modo $nome', () {
      final c = tema.colorScheme;
      final cores = tema.extension<AppColors>()!;
      final fundos = {'fundo': c.surface, 'bloco': c.surfaceContainerLowest};

      test('o tema regista as cores da app', () {
        expect(tema.extension<AppColors>(), isNotNull);
      });

      test('texto principal e secundário passam o AA (4,5:1) no fundo e nos blocos', () {
        for (final MapEntry(key: onde, value: fundo) in fundos.entries) {
          expect(contraste(c.onSurface, fundo), greaterThanOrEqualTo(4.5), reason: 'onSurface no $onde');
          expect(contraste(c.onSurfaceVariant, fundo), greaterThanOrEqualTo(4.5), reason: 'onSurfaceVariant no $onde');
          expect(contraste(c.primary, fundo), greaterThanOrEqualTo(4.5), reason: 'primary no $onde');
        }
      });

      test('o contorno dos campos vê-se (3:1, WCAG 1.4.11)', () {
        for (final MapEntry(key: onde, value: fundo) in fundos.entries) {
          expect(contraste(c.outline, fundo), greaterThanOrEqualTo(3), reason: 'outline no $onde');
        }
      });

      test('cada estado lê-se no seu fundo e na superfície', () {
        final estados = {
          'success': cores.success,
          'warning': cores.warning,
          'error': cores.error,
          'info': cores.info,
          'neutral': cores.neutral,
        };
        for (final MapEntry(key: nomeEstado, value: e) in estados.entries) {
          expect(contraste(e.foreground, e.container), greaterThanOrEqualTo(4.5), reason: '$nomeEstado no fundo');
          expect(e.container.a, 1, reason: '$nomeEstado: o fundo tem de ser opaco');
          for (final MapEntry(key: onde, value: fundo) in fundos.entries) {
            expect(contraste(e.foreground, fundo), greaterThanOrEqualTo(4.5), reason: '$nomeEstado no $onde');
          }
        }
      });

      test('o texto sobre o gradiente do clube passa o AA em todas as paragens', () {
        for (final paragem in cores.brandGradient.colors) {
          expect(contraste(cores.onBrand, paragem), greaterThanOrEqualTo(4.5));
          expect(contraste(sobre(cores.onBrandMuted, paragem), paragem), greaterThanOrEqualTo(4.5));
        }
      });

      test('erro do esquema passa o AA', () {
        expect(contraste(c.error, c.surfaceContainerLowest), greaterThanOrEqualTo(4.5));
        expect(contraste(c.onErrorContainer, c.errorContainer), greaterThanOrEqualTo(4.5));
      });

      test('nenhum texto do tema abaixo de 12 px', () {
        final t = tema.textTheme;
        for (final estilo in [
          t.displaySmall, t.headlineLarge, t.headlineMedium, t.headlineSmall, t.titleLarge, t.titleMedium, //
          t.titleSmall, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall,
        ]) {
          expect(estilo!.fontSize, greaterThanOrEqualTo(12));
          expect(estilo.fontFamily, 'Inter');
        }
      });
    });
  }

  test('AppColors interpola entre claro e escuro sem perder campos', () {
    final meio = AppColors.light.lerp(AppColors.dark, 0.5);
    expect(
      meio.success.foreground,
      Color.lerp(AppColors.light.success.foreground, AppColors.dark.success.foreground, 0.5),
    );
    expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
  });
}
