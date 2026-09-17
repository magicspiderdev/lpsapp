import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/clientes.dart';
import '../api/envelope.dart';

/// O que o `/ping` diz sobre esta versão da app (guia §4.1).
class EstadoVersao {
  final bool bloquear;
  final bool sugerir;
  final String? urlLoja;

  const EstadoVersao({this.bloquear = false, this.sugerir = false, this.urlLoja});

  /// Sem resposta do servidor não se bloqueia: o cartão tem de abrir sem rede.
  static const semInformacao = EstadoVersao();
}

/// Compara versões por componentes numéricos (`1.10.0` > `1.9.0`).
int compararVersoes(String a, String b) {
  List<int> partes(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = partes(a), pb = partes(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

final estadoVersaoProvider = FutureProvider<EstadoVersao>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    // Curto: sem rede, o arranque não pode ficar à espera.
    final data = await dadosDe(ref.read(dioSocioProvider).get('/ping')).timeout(const Duration(seconds: 5));
    final app = (data['app'] as Map?)?.cast<String, dynamic>() ?? const {};
    final minima = app['versao_minima'] as String?;
    final atual = app['versao_atual'] as String?;
    final url = defaultTargetPlatform == TargetPlatform.iOS ? app['url_ios'] as String? : app['url_android'] as String?;
    return EstadoVersao(
      bloquear: minima != null && compararVersoes(info.version, minima) < 0,
      sugerir: atual != null && compararVersoes(info.version, atual) < 0,
      urlLoja: url,
    );
  } catch (_) {
    return EstadoVersao.semInformacao;
  }
});
