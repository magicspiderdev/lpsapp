import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart' as auth;
import '../../../core/formatos.dart';
import 'bilheteira.dart';

/// Comprar bilhetes: `POST /api/v2/me/bilhetes/encomendas` e o que vem depois
/// (guia §4.18). Com o token da **conta** — comprar não exige ser sócio, só as
/// zonas que o clube marcar é que exigem.
///
/// Duas coisas que o contrato impõe e que se notam no ecrã:
///
/// - **Uma encomenda é de uma zona.** O pedido leva `{sessao, zona,
///   quantidade}`: dois tipos de bilhete são duas compras, e é por isso que o
///   ecrã da sessão escolhe uma zona de cada vez em vez de somar tudo.
/// - **Um `201` não significa pago.** Uma zona gratuita nasce `paga` e já traz
///   os bilhetes; uma paga nasce `pendente` e a confirmação chega do IfthenPay
///   mais tarde — acompanha-se em `GET …/encomendas/{id}`.
class PagamentoBilhetes {
  /// `mbway` ou `paybylink`. **Pode não ser o que se pediu**: um MB WAY que
  /// falha no IfthenPay cai para `paybylink`, como nas quotas.
  final String metodo;

  /// Nº do pagamento, o mesmo que aparece no histórico do sócio.
  final int? referencia;
  final double total;

  /// `paybylink`: a página onde se paga (Multibanco, cartão).
  final String? urlPagamento;
  final String? pincode, requestId;

  /// `mbway`: até quando aprovar. `paybylink`: até quando os lugares ficam
  /// guardados.
  final DateTime? expiraEm;

  const PagamentoBilhetes({
    required this.metodo,
    required this.total,
    this.referencia,
    this.urlPagamento,
    this.pincode,
    this.requestId,
    this.expiraEm,
  });

  factory PagamentoBilhetes.fromJson(Map<String, dynamic> j) => PagamentoBilhetes(
    metodo: ((j['metodo'] ?? 'paybylink') as String).toLowerCase(),
    total: ((j['total'] as num?) ?? 0).toDouble(),
    referencia: (j['referencia'] as num?)?.toInt(),
    urlPagamento: j['url_pagamento'] as String?,
    pincode: j['pincode'] as String?,
    requestId: j['request_id'] as String?,
    expiraEm: dataApi(j['expira_em']),
  );

  bool get mbway => metodo == 'mbway';
  bool get temLink => (urlPagamento ?? '').isNotEmpty;
}

/// Uma compra: a zona, quantos, quanto, e os bilhetes quando já está paga.
class Encomenda {
  final String id;

  /// `pendente`, `paga`, `expirada`, `cancelada` — lista aberta.
  final String estado;
  final String? sessao, titulo, zona;
  final DateTime? inicio;
  final int quantidade;

  /// `preco` é por bilhete; `total` é o que se paga.
  final double preco, total;

  /// `gratis`, `mbway`, `paybylink` — o que o servidor decidiu.
  final String? metodo;

  /// Só em `pendente`: até quando os lugares ficam guardados.
  final DateTime? expiraEm, pagoEm;

  /// Vazia enquanto não está paga.
  final List<BilheteComprado> bilhetes;

  const Encomenda({
    required this.id,
    required this.estado,
    this.sessao,
    this.titulo,
    this.zona,
    this.inicio,
    this.quantidade = 0,
    this.preco = 0,
    this.total = 0,
    this.metodo,
    this.expiraEm,
    this.pagoEm,
    this.bilhetes = const [],
  });

  factory Encomenda.fromJson(Map<String, dynamic> j) {
    final sessao = (j['sessao'] as Map?)?.cast<String, dynamic>();
    final zona = (j['zona'] as Map?)?.cast<String, dynamic>();
    return Encomenda(
      id: j['id'].toString(),
      estado: ((j['estado'] ?? 'pendente') as String).toLowerCase(),
      sessao: sessao?['id']?.toString(),
      titulo: sessao?['titulo'] as String?,
      inicio: dataApi(sessao?['inicio']),
      zona: zona?['nome'] as String?,
      quantidade: (j['quantidade'] as num?)?.toInt() ?? 0,
      preco: ((j['preco'] as num?) ?? 0).toDouble(),
      total: ((j['total'] as num?) ?? 0).toDouble(),
      metodo: (j['metodo'] as String?)?.toLowerCase(),
      expiraEm: dataApi(j['expira_em']),
      pagoEm: dataApi(j['pago_em']),
      bilhetes: [
        for (final b in (j['bilhetes'] as List?) ?? const [])
          if (b is Map) BilheteComprado.fromJson(b.cast<String, dynamic>()),
      ],
    );
  }

  bool get paga => estado == 'paga';
  bool get pendente => estado == 'pendente';
  bool get cancelada => estado == 'cancelada';

  /// Por pagar e já sem lugares guardados. **Não é uma compra perdida**: um
  /// pagamento que chegue na mesma é aceite e emite os bilhetes (§4.18).
  bool get expirada => estado == 'expirada';

  /// Nada a pagar: saiu logo paga.
  bool get gratis => metodo == 'gratis' || (total == 0 && paga);
}

/// O que um `POST` ou um `GET` de uma encomenda devolvem.
class Compra {
  final Encomenda encomenda;

  /// `null` nas gratuitas e depois de paga.
  final PagamentoBilhetes? pagamento;

  const Compra({required this.encomenda, this.pagamento});

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
    encomenda: Encomenda.fromJson(((j['encomenda'] as Map?) ?? const {}).cast<String, dynamic>()),
    pagamento: j['pagamento'] is Map
        ? PagamentoBilhetes.fromJson((j['pagamento'] as Map).cast<String, dynamic>())
        : null,
  );
}

/// As chamadas da compra. Nunca com cache e nunca repetidas sozinhas: cada
/// `POST` guarda lugares e pode criar um pagamento.
class Bilheteira {
  const Bilheteira(this._dio);

  final Dio _dio;

  /// Uma zona de cada vez, como o contrato pede. `metodo` e `telefone`
  /// ignoram-se nas gratuitas — e não se enviam valores: o total é o que a
  /// resposta disser.
  Future<Compra> comprar({
    required String sessao,
    required String zona,
    required int quantidade,
    String? metodo,
    String? telefone,
  }) async => Compra.fromJson(
    await dadosDe(
      _dio.post('/me/bilhetes/encomendas', data: {
        'sessao': sessao,
        'zona': int.tryParse(zona) ?? zona,
        'quantidade': quantidade,
        'metodo': ?metodo,
        if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
      }),
    ),
  );

  Future<Compra> estado(String id) async =>
      Compra.fromJson(await dadosDe(_dio.get('/me/bilhetes/encomendas/$id')));

  /// Desistir de uma compra por pagar: os lugares voltam à venda.
  Future<void> desistir(String id) => dadosDe(_dio.delete('/me/bilhetes/encomendas/$id'));
}

final bilheteiraProvider = Provider<Bilheteira>((ref) => Bilheteira(ref.read(dioContaProvider)));

/// Quem pode levar esta zona, com a sessão que há.
///
/// `exige_socio` vem no contrato precisamente para se **explicar antes** de
/// alguém preencher um formulário para ouvir um `403` (esquema `Zona`). O
/// resto decide-se no servidor: a app não deduz regras do preço.
enum QuemPode {
  /// Pode avançar.
  podeComprar,

  /// Não há sessão nenhuma: entrar (ou criar conta) e voltar aqui.
  precisaDeConta,

  /// Tem conta sem ficha e a zona é só de sócios: associar a ficha.
  precisaDeSocio,

  /// `venda: externa` (ou um valor que a app não conhece): compra-se fora.
  foraDaApp,

  /// Esgotada ou a venda fechada.
  indisponivel,

  /// A conta não pode comprar (`permissoes.comprar: false`, §2.10) — nem
  /// bilhetes gratuitos. Quem compra é o encarregado de educação.
  soEncarregado,
}

QuemPode quemPodeComprar(auth.Sessao quem, Zona zona, {required bool sessaoAVenda}) {
  if (!sessaoAVenda || !zona.disponivel) return QuemPode.indisponivel;
  if (!zona.naApp) return QuemPode.foraDaApp;
  // Antes da ficha de sócio: associá-la não mudava nada.
  if (!auth.sessaoPode(quem, 'comprar')) return QuemPode.soEncarregado;
  return switch (quem) {
    auth.SessaoAnonima() => QuemPode.precisaDeConta,
    auth.SessaoConta() when zona.exigeSocio => QuemPode.precisaDeSocio,
    _ => QuemPode.podeComprar,
  };
}
