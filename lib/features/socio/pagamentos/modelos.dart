import '../../../core/formatos.dart';

double? _dinheiro(Object? v) => (v as num?)?.toDouble();

// ── Quotas (guia §4.5) ──────────────────────────────────────────────────────

enum EstadoMes { pago, pagoLegacy, pendente, futuro, isento, desconhecido }

EstadoMes estadoMesDe(Object? s) => switch (s) {
  'pago' => EstadoMes.pago,
  'pago_legacy' => EstadoMes.pagoLegacy,
  'pendente' => EstadoMes.pendente,
  'futuro' => EstadoMes.futuro,
  'isento' => EstadoMes.isento,
  _ => EstadoMes.desconhecido, // a API pode ganhar estados novos
};

class MesQuota {
  final DateTime mes;
  final String mesLabel;
  final EstadoMes estado;

  /// `null` em `pago_legacy`: sem valor conhecido, **não** é zero.
  final double? valor;
  final String? tipo;
  final DateTime? pagoEm;

  const MesQuota({required this.mes, required this.mesLabel, required this.estado, this.valor, this.tipo, this.pagoEm});

  factory MesQuota.fromJson(Map<String, dynamic> j) => MesQuota(
    mes: DateTime.parse(j['mes'] as String),
    mesLabel: j['mes_label'] as String,
    estado: estadoMesDe(j['estado']),
    valor: _dinheiro(j['valor']),
    tipo: j['tipo'] as String?,
    pagoEm: dataApi(j['pago_em']),
  );

  bool get pago => estado == EstadoMes.pago || estado == EstadoMes.pagoLegacy;
}

/// Uma ordem de pagamento de quotas ainda por pagar.
class OrdemPendente {
  final int idPagamento;
  final double valor;
  final String meses;

  /// Normalizado para minúsculas: a lista vem em maiúsculas, o pagamento em minúsculas.
  final String metodo;
  final String? urlPagamento, referencia;
  final DateTime? limite, criadoEm;

  /// `false` = criada pela secretaria; não se pode cancelar na app.
  final bool cancelavel;

  const OrdemPendente({
    required this.idPagamento,
    required this.valor,
    required this.meses,
    required this.metodo,
    required this.cancelavel,
    this.urlPagamento,
    this.referencia,
    this.limite,
    this.criadoEm,
  });

  factory OrdemPendente.fromJson(Map<String, dynamic> j) => OrdemPendente(
    idPagamento: j['id_pagamento'] as int,
    valor: _dinheiro(j['valor']) ?? 0,
    meses: (j['meses'] ?? '') as String,
    metodo: ((j['metodo'] ?? '') as String).toLowerCase(),
    cancelavel: j['cancelavel'] == true,
    urlPagamento: j['url_pagamento'] as String?,
    referencia: j['referencia']?.toString(),
    limite: dataApi(j['limite']),
    criadoEm: dataApi(j['criado_em']),
  );
}

class Quotas {
  final bool isento;
  final DateTime? ultimaQuota;
  final double totalPendente;

  /// Nº mínimo de meses por pagamento: o seletor começa aqui.
  final int minimoPagamento;
  final List<MesQuota> caderneta, selecionaveis;
  final List<OrdemPendente> ordensPendentes;

  const Quotas({
    required this.isento,
    required this.totalPendente,
    required this.minimoPagamento,
    required this.caderneta,
    required this.selecionaveis,
    required this.ordensPendentes,
    this.ultimaQuota,
  });

  factory Quotas.fromJson(Map<String, dynamic> j) => Quotas(
    isento: j['isento'] == true,
    ultimaQuota: dataApi(j['ultima_quota']),
    totalPendente: _dinheiro(j['total_pendente']) ?? 0,
    minimoPagamento: (j['minimo_pagamento'] as int?) ?? 1,
    caderneta: [for (final m in j['caderneta'] as List) MesQuota.fromJson((m as Map).cast<String, dynamic>())],
    selecionaveis: [
      for (final m in (j['selecionaveis'] as List?) ?? const []) MesQuota.fromJson((m as Map).cast<String, dynamic>()),
    ],
    ordensPendentes: [
      for (final o in (j['ordens_pendentes'] as List?) ?? const [])
        OrdemPendente.fromJson((o as Map).cast<String, dynamic>()),
    ],
  );

  /// Isento, ou nada que se possa pagar: sem botão de pagamento.
  bool get podePagar => !isento && selecionaveis.isNotEmpty;
}

// ── Faturas (guia §4.8) ─────────────────────────────────────────────────────

class Fatura {
  final int id;
  final DateTime? mesAno;
  final String mesLabel, estado;
  final double valorTotal, valorPago;
  final bool paga;

  /// Número fiscal; hoje quase sempre `null` — não mostrar nesse caso.
  final String? nrFatura;
  final DateTime? geradoEm;

  const Fatura({
    required this.id,
    required this.mesLabel,
    required this.estado,
    required this.valorTotal,
    required this.valorPago,
    required this.paga,
    this.mesAno,
    this.nrFatura,
    this.geradoEm,
  });

  factory Fatura.fromJson(Map<String, dynamic> j) => Fatura(
    id: j['id'] as int,
    mesAno: dataApi(j['mes_ano']),
    mesLabel: (j['mes_label'] ?? '') as String,
    estado: (j['estado'] ?? '') as String,
    valorTotal: _dinheiro(j['valor_total']) ?? 0,
    valorPago: _dinheiro(j['valor_pago']) ?? 0,
    paga: j['paga'] == true,
    nrFatura: j['nr_fatura']?.toString(),
    geradoEm: dataApi(j['gerado_em']),
  );

  double get emFalta => (valorTotal - valorPago).clamp(0, double.infinity);
}

class LinhaFatura {
  final String descricao, tipo;
  final double valor;

  const LinhaFatura({required this.descricao, required this.tipo, required this.valor});

  factory LinhaFatura.fromJson(Map<String, dynamic> j) => LinhaFatura(
    descricao: (j['descricao'] ?? '') as String,
    tipo: (j['tipo'] ?? '') as String,
    valor: _dinheiro(j['valor']) ?? 0,
  );

  /// `quota` e `"quota sócio"` existem os dois em produção: comparar por prefixo.
  bool get eQuota => tipo.toLowerCase().startsWith('quota');
}

/// Pagamento associado a uma fatura ou do histórico (guia §4.8 e §4.10).
class Pagamento {
  final int idPagamento;
  final String? referencia, descricao, metodo, urlPagamento;

  /// `PAGO`, `PENDENTE`, `CANCELADO`, `ANULADO`, `RENOVADO` — lista aberta.
  final String estado;
  final double valor;
  final DateTime? data, pagoEm, limite;
  final bool cancelavel;

  const Pagamento({
    required this.idPagamento,
    required this.estado,
    required this.valor,
    this.referencia,
    this.descricao,
    this.metodo,
    this.urlPagamento,
    this.data,
    this.pagoEm,
    this.limite,
    this.cancelavel = false,
  });

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
    idPagamento: j['id_pagamento'] as int,
    estado: ((j['estado'] ?? '') as String).toUpperCase(),
    valor: _dinheiro(j['valor']) ?? 0,
    referencia: j['referencia']?.toString(),
    descricao: j['descricao'] as String?,
    metodo: (j['metodo'] as String?)?.toLowerCase(),
    urlPagamento: j['url_pagamento'] as String?,
    data: dataApi(j['data']),
    pagoEm: dataApi(j['pago_em']),
    limite: dataApi(j['limite']),
    cancelavel: j['cancelavel'] == true,
  );

  bool get pago => estado == 'PAGO';
  bool get pendente => estado == 'PENDENTE';
}

class DetalheFatura {
  final Fatura fatura;
  final List<LinhaFatura> linhas;

  /// `null` quando ainda não foi gerado nenhum pagamento.
  final Pagamento? pagamento;

  const DetalheFatura({required this.fatura, required this.linhas, this.pagamento});

  factory DetalheFatura.fromJson(Map<String, dynamic> j) => DetalheFatura(
    fatura: Fatura.fromJson((j['fatura'] as Map).cast<String, dynamic>()),
    linhas: [
      for (final l in (j['linhas'] as List?) ?? const []) LinhaFatura.fromJson((l as Map).cast<String, dynamic>()),
    ],
    pagamento: j['pagamento'] is Map ? Pagamento.fromJson((j['pagamento'] as Map).cast<String, dynamic>()) : null,
  );
}

// ── Resultado de pedir um pagamento (guia §4.11–4.12) ───────────────────────

class ResultadoPagamento {
  final int idPagamento;
  final String? referencia;

  /// O total calculado pelo servidor — é este que se mostra, não o que se escolheu.
  final double total;

  /// O método **da resposta** manda: um MB WAY que falhe volta como `paybylink`.
  final String metodo;
  final String? urlPagamento, pincode, requestId;
  final List<String> meses;
  final DateTime? limite, expiraEm;

  /// `true` = não foi criada cobrança nova; é a que já existia.
  final bool reutilizado;

  const ResultadoPagamento({
    required this.idPagamento,
    required this.total,
    required this.metodo,
    this.referencia,
    this.urlPagamento,
    this.pincode,
    this.requestId,
    this.meses = const [],
    this.limite,
    this.expiraEm,
    this.reutilizado = false,
  });

  factory ResultadoPagamento.fromJson(Map<String, dynamic> j) => ResultadoPagamento(
    idPagamento: j['id_pagamento'] as int,
    referencia: j['referencia']?.toString(),
    total: _dinheiro(j['total']) ?? _dinheiro(j['valor']) ?? 0,
    metodo: ((j['metodo'] ?? '') as String).toLowerCase(),
    urlPagamento: j['url_pagamento'] as String?,
    pincode: j['pincode']?.toString(),
    requestId: j['request_id']?.toString(),
    meses: [for (final m in (j['meses'] as List?) ?? const []) m.toString()],
    limite: dataApi(j['limite']),
    expiraEm: dataApi(j['expira_em']),
    reutilizado: j['reutilizado'] == true,
  );

  bool get mbway => metodo == 'mbway';
  bool get temLink => urlPagamento != null;
}

// ── Mensalidades das modalidades (guia §4.6) ────────────────────────────────

class Subscricao {
  final int id;
  final String modalidade;
  final String? epoca;
  final bool ativa;

  /// A mensalidade já inclui a quota de sócio.
  final bool incluiQuota;
  final DateTime? dataInicio, dataFim;

  /// `null` = preço por escalão etário.
  final double? valorFixo;

  const Subscricao({
    required this.id,
    required this.modalidade,
    required this.ativa,
    required this.incluiQuota,
    this.epoca,
    this.dataInicio,
    this.dataFim,
    this.valorFixo,
  });

  factory Subscricao.fromJson(Map<String, dynamic> j) => Subscricao(
    id: j['id'] as int,
    modalidade: (j['modalidade'] ?? '') as String,
    epoca: j['epoca'] as String?,
    ativa: j['ativa'] == true,
    incluiQuota: j['inclui_quota'] == true,
    dataInicio: dataApi(j['data_inicio']),
    dataFim: dataApi(j['data_fim']),
    valorFixo: _dinheiro(j['valor_fixo']),
  );
}

class MesModalidade {
  final DateTime mes;
  final String mesLabel, estado;
  final double valor;

  /// Previsão: a fatura ainda não foi emitida. Não é dívida e não se paga.
  final bool estimado;
  final int? idFatura;

  const MesModalidade({
    required this.mes,
    required this.mesLabel,
    required this.estado,
    required this.valor,
    required this.estimado,
    this.idFatura,
  });

  factory MesModalidade.fromJson(Map<String, dynamic> j) => MesModalidade(
    mes: DateTime.parse(j['mes'] as String),
    mesLabel: (j['mes_label'] ?? '') as String,
    estado: (j['estado'] ?? '') as String,
    valor: _dinheiro(j['valor']) ?? 0,
    estimado: j['estimado'] == true,
    idFatura: j['id_fatura'] as int?,
  );

  bool get pagavel => !estimado && idFatura != null && estado == 'pendente';
}

class Mensalidades {
  final double totalPendente;
  final List<Subscricao> subscricoes;
  final List<MesModalidade> caderneta;

  const Mensalidades({required this.totalPendente, required this.subscricoes, required this.caderneta});

  factory Mensalidades.fromJson(Map<String, dynamic> j) => Mensalidades(
    totalPendente: _dinheiro(j['total_pendente']) ?? 0,
    subscricoes: [
      for (final s in (j['subscricoes'] as List?) ?? const []) Subscricao.fromJson((s as Map).cast<String, dynamic>()),
    ],
    caderneta: [
      for (final m in (j['caderneta'] as List?) ?? const []) MesModalidade.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );
}

// ── Conta corrente (guia §4.7) ──────────────────────────────────────────────

class MovimentoWallet {
  final int id;

  /// `credito` ou `debito`; o valor vem sempre positivo.
  final String tipo;
  final double valor;
  final String? descricao;
  final DateTime? data;

  const MovimentoWallet({required this.id, required this.tipo, required this.valor, this.descricao, this.data});

  factory MovimentoWallet.fromJson(Map<String, dynamic> j) => MovimentoWallet(
    id: (j['id'] as int?) ?? 0,
    tipo: ((j['tipo'] ?? '') as String).toLowerCase(),
    valor: _dinheiro(j['valor']) ?? 0,
    descricao: j['descricao'] as String?,
    data: dataApi(j['data']),
  );

  bool get credito => tipo == 'credito';
}

class Wallet {
  /// Positivo = crédito a favor do sócio.
  final double saldo;
  final List<MovimentoWallet> movimentos;

  const Wallet({required this.saldo, required this.movimentos});

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
    saldo: _dinheiro(j['saldo']) ?? 0,
    movimentos: [
      for (final m in (j['movimentos'] as List?) ?? const [])
        MovimentoWallet.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );
}
