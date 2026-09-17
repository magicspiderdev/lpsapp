import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/auth/token_store.dart';

/// `GET /me/cartao` (guia §4.4).
///
/// `hashid` e `qrConteudo` são a credencial que a portaria valida: não vão
/// para logs e só se guardam no armazenamento seguro.
class Cartao {
  final int nrSocio, estado;
  final String nomeCompleto, estadoLabel, qrConteudo;
  final String? fotoUrl;
  final DateTime? dataSocio;
  final bool valido;

  const Cartao({
    required this.nrSocio,
    required this.estado,
    required this.nomeCompleto,
    required this.estadoLabel,
    required this.qrConteudo,
    required this.valido,
    this.fotoUrl,
    this.dataSocio,
  });

  factory Cartao.fromJson(Map<String, dynamic> j) => Cartao(
        nrSocio: j['nr_socio'] as int,
        estado: j['estado'] as int,
        nomeCompleto: j['nome_completo'] as String,
        estadoLabel: j['estado_label'] as String,
        qrConteudo: j['qr_conteudo'] as String,
        valido: j['valido'] as bool,
        fotoUrl: j['foto_url'] as String?,
        dataSocio: j['data_socio'] is String ? DateTime.tryParse(j['data_socio'] as String) : null,
      );
}

/// O cartão e de onde veio: sem rede mostra-se o último guardado.
class EstadoCartao {
  final Cartao? cartao;

  /// `409 sem_cartao`: o sócio ainda não tem cartão emitido.
  final bool semCartao;

  /// Quando foi obtido do servidor; `deCache` se não foi possível actualizar agora.
  final DateTime? obtidoEm;
  final bool deCache;

  const EstadoCartao({this.cartao, this.semCartao = false, this.obtidoEm, this.deCache = false});
}

const _kCache = '${TokenStore.prefixoCache}cartao';

final cartaoProvider = FutureProvider.autoDispose<EstadoCartao>((ref) async {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');

  const storage = FlutterSecureStorage();
  // A cache é do sócio que a guardou; outro sócio no mesmo aparelho não a vê.
  final chave = '$_kCache.${sessao.socio.nrSocio}';

  try {
    final data = await dadosDe(ref.read(dioSocioProvider).get('/me/cartao'));
    final agora = DateTime.now();
    await storage.write(key: chave, value: jsonEncode({'obtido_em': agora.toIso8601String(), 'cartao': data}));
    return EstadoCartao(cartao: Cartao.fromJson(data), obtidoEm: agora);
  } on ApiException catch (e) {
    if (e.erro == 'sem_cartao') {
      await storage.delete(key: chave);
      return const EstadoCartao(semCartao: true);
    }
    // Sem rede ou servidor em baixo: o cartão tem de abrir na mesma.
    final guardado = await _lerCache(storage, chave);
    if (guardado != null) return guardado;
    rethrow;
  }
});

Future<EstadoCartao?> _lerCache(FlutterSecureStorage storage, String chave) async {
  try {
    final bruto = await storage.read(key: chave);
    if (bruto == null) return null;
    final j = jsonDecode(bruto) as Map<String, dynamic>;
    return EstadoCartao(
      cartao: Cartao.fromJson((j['cartao'] as Map).cast<String, dynamic>()),
      obtidoEm: DateTime.tryParse(j['obtido_em'] as String? ?? ''),
      deCache: true,
    );
  } catch (_) {
    return null;
  }
}
