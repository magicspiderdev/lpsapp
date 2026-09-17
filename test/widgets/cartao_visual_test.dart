import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/core/tema/tema.dart';
import 'package:lpsapp/features/socio/cartao/cartao_page.dart';

/// O cartão tem altura fixa (proporção da imagem): nome, número e estado têm de
/// caber em qualquer largura de ecrã e com a letra do sistema aumentada.
void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  const nomes = {
    'curto': 'ANA SÁ',
    'normal': 'MARIA EXEMPLO DA SILVA SANTOS',
    'longo': 'MARIA DA CONCEIÇÃO RODRIGUES DOS SANTOS FERREIRA DA SILVA E ALBUQUERQUE MONTEIRO',
    'palavra sem espaços': 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ',
  };

  for (final largura in [280.0, 320.0, 360.0, 430.0]) {
    for (final escala in [1.0, 1.3, 2.0, 3.0]) {
      for (final foto in [false, true]) {
        for (final MapEntry(key: caso, value: nome) in nomes.entries) {
          testWidgets('$caso · ${largura.toInt()}px · letra x$escala · ${foto ? 'com' : 'sem'} foto', (t) async {
            t.view.physicalSize = Size(largura, 800);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);

            await t.pumpWidget(
              MaterialApp(
                theme: Tema.claro(),
                home: MediaQuery(
                  data: MediaQueryData(size: Size(largura, 800), textScaler: TextScaler.linear(escala)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CartaoVisual(
                            nome: nome,
                            nrSocio: 123456,
                            estadoLabel: 'Por definir',
                            valido: false,
                            dataSocio: DateTime(2025, 9, 3),
                            fotoUrl: foto ? 'https://exemplo.invalido/foto.jpg' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pump();

            // Um overflow do Flutter chega aqui como excepção.
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }
}
