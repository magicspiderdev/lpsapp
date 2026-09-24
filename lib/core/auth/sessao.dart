import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/clientes.dart';
import '../api/envelope.dart';
import '../push/push.dart';

/// O sócio tal como vem no bloco `socio` do login.
class SocioSessao {
  final int nrSocio;
  final String nomeCompleto;
  final String? email;
  final String? fotoUrl;
  final int estado;

  const SocioSessao({
    required this.nrSocio,
    required this.nomeCompleto,
    required this.estado,
    this.email,
    this.fotoUrl,
  });

  factory SocioSessao.fromJson(Map<String, dynamic> j) => SocioSessao(
    nrSocio: (j['nr_socio'] as num).toInt(),
    nomeCompleto: (j['nome_completo'] ?? '') as String,
    estado: (j['estado'] as num?)?.toInt() ?? 0,
    email: j['email'] as String?,
    fotoUrl: j['foto_url'] as String?,
  );
}

/// A conta da app (v2). Existe com ou sem ficha de sócio associada.
class ContaSessao {
  /// `null` nas contas que entraram pelo número de sócio e nunca puseram email.
  final String? email;
  final String nome;
  final bool emailVerificado, comunicacoes;

  /// A ficha de sócio, quando a conta tem uma. É o que abre a zona privada.
  final SocioSessao? socio;

  /// `conta.permissoes` (§2.10): o que o servidor deixa esta conta fazer. É
  /// lista aberta — o que não vem, ou não se conhece, conta como permitido e
  /// fica para o servidor recusar. **A app nunca calcula idades.**
  final Map<String, bool> permissoes;

  /// Só para explicar porquê: com uma permissão a `false`, quem faz isso é o
  /// encarregado de educação.
  final bool menor;

  const ContaSessao({
    required this.nome,
    this.email,
    this.emailVerificado = false,
    this.comunicacoes = false,
    this.socio,
    this.permissoes = const {},
    this.menor = false,
  });

  bool pode(String permissao) => permissoes[permissao] != false;

  bool get podePagar => pode('pagar');
  bool get podeComprar => pode('comprar');
  bool get podeContratar => pode('contratar');
  bool get podeComunidade => pode('comunidade');
  bool get podePassatempos => pode('passatempos');

  factory ContaSessao.fromJson(Map<String, dynamic> j) => ContaSessao(
    email: j['email'] as String?,
    nome: (j['nome'] ?? '') as String,
    emailVerificado: j['email_verificado'] == true,
    comunicacoes: j['comunicacoes'] == true,
    socio: j['socio'] is Map ? SocioSessao.fromJson((j['socio'] as Map).cast<String, dynamic>()) : null,
    permissoes: {
      if (j['permissoes'] case final Map p)
        for (final MapEntry(:key, :value) in p.entries)
          if (key is String && value is bool) key: value,
    },
    menor: j['menor'] == true,
  );
}

/// Quem está a usar a app. São três estados, não dois: a app não é só para
/// sócios, e quem tem conta sem ficha não é um anónimo.
sealed class Sessao {
  const Sessao();
}

/// Sem sessão nenhuma: só a zona pública.
class SessaoAnonima extends Sessao {
  const SessaoAnonima();
}

/// Conta sem ficha de sócio: funções pessoais (bilhetes, interesses,
/// inscrição), mas a zona privada fica fechada.
class SessaoConta extends Sessao {
  final ContaSessao conta;
  const SessaoConta(this.conta);
}

/// Conta com ficha de sócio: abre também a zona privada (`/api/v1`).
///
/// Só se constrói a partir de uma conta que **tem** ficha — é [sessaoDaConta]
/// que decide, e é por isso que o [socio] pode ser lido sem hesitação.
class SessaoSocio extends Sessao {
  final ContaSessao conta;

  SessaoSocio(this.conta) : assert(conta.socio != null, 'SessaoSocio sem ficha de sócio');

  SocioSessao get socio => conta.socio!;
}

/// Uma sessão de sócio a partir só da ficha, para os testes não terem de
/// montar a conta à volta dela.
@visibleForTesting
SessaoSocio sessaoDeSocio(SocioSessao socio) =>
    SessaoSocio(ContaSessao(nome: socio.nomeCompleto, email: socio.email, socio: socio));

/// A conta de quem tem sessão, seja ela de sócio ou não.
ContaSessao? contaDe(Sessao s) => switch (s) {
  SessaoConta(:final conta) => conta,
  SessaoSocio(:final conta) => conta,
  SessaoAnonima() => null,
};

/// Se quem tem sessão pode fazer [permissao] (§2.10). Sem sessão, sim: o que
/// falta aí é entrar, e isso decide-se noutro lado.
bool sessaoPode(Sessao s, String permissao) => contaDe(s)?.pode(permissao) ?? true;

/// A frase que fica no lugar de um botão escondido por uma permissão a
/// `false`. O servidor não a manda antes de se tentar; a do `403
/// menor_de_idade` vem na resposta.
String explicacaoPermissao(String permissao) => switch (permissao) {
  'pagar' => 'Os pagamentos são feitos pelo encarregado de educação.',
  'comprar' => 'Os bilhetes são comprados pelo encarregado de educação.',
  'contratar' => 'As inscrições são feitas pelo encarregado de educação.',
  _ => 'Isto é feito pelo encarregado de educação.',
};

/// Estado a partir do bloco `conta` da sessão.
Sessao sessaoDaConta(Map<String, dynamic> json) {
  final conta = ContaSessao.fromJson(json);
  return conta.socio == null ? SessaoConta(conta) : SessaoSocio(conta);
}

final sessaoProvider = NotifierProvider<SessaoController, Sessao>(SessaoController.new);


class SessaoController extends Notifier<Sessao> {
  StreamSubscription<void>? _sub;
  StreamSubscription<Map<String, dynamic>>? _subConta;

  @override
  Sessao build() {
    final store = ref.watch(tokenStoreProvider);
    _sub?.cancel();
    _sub = store.sessaoTerminada.listen((_) => state = const SessaoAnonima());
    // A idade muda sem ninguém entrar: cada refresh traz a `conta` com as
    // permissões do dia (§2.10).
    _subConta?.cancel();
    _subConta = store.contaRenovada.listen((conta) {
      if (state is! SessaoAnonima) state = sessaoDaConta(conta);
    });
    ref.onDispose(() {
      _sub?.cancel();
      _subConta?.cancel();
    });

    final conta = store.conta;
    return store.temSessao && conta != null ? sessaoDaConta(conta) : const SessaoAnonima();
  }

  // ── Entrar ───────────────────────────────────────────────────────────────

  /// `POST /auth/login` com email **ou** número de sócio (§2.9).
  ///
  /// O login por número é permanente e usa a password da app antiga: quem já
  /// era sócio entra sem se registar, e a conta fica sem email até querer um.
  Future<void> entrar({String? email, int? nrSocio, required String password}) async {
    assert((email == null) != (nrSocio == null), 'email ou nr_socio, um deles');
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/login', data: {
        'email': ?email,
        'nr_socio': ?nrSocio,
        'password': password,
      }),
    );
    await _abrir(data);
  }

  // ── Criar conta ──────────────────────────────────────────────────────────

  /// `POST /auth/registo`. A resposta é a mesma exista ou não o email — nunca
  /// diz quem já tem conta. Devolve a `mensagem` para mostrar.
  Future<String> registar({
    required String email,
    required String password,
    required String nome,
    required DateTime dataNascimento,
    bool comunicacoes = false,
  }) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/registo', data: {
        'email': email,
        'password': password,
        'nome': nome,
        'data_nascimento': _dia(dataNascimento),
        'aceita_termos': true,
        'termos_versao': versaoTermos,
        'privacidade_versao': versaoPrivacidade,
        'comunicacoes': comunicacoes,
      }),
    );
    return (data['mensagem'] as String?) ?? 'Enviámos um código para o seu email.';
  }

  /// `POST /auth/registo/confirmar`: o código do email fecha o registo e abre
  /// logo a sessão.
  Future<void> confirmarRegisto({required String email, required String codigo}) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/registo/confirmar', data: {'email': email, 'codigo': codigo}),
    );
    await _abrir(data);
  }

  // ── Password ─────────────────────────────────────────────────────────────

  /// `POST /auth/password/pedir` por email ou por número de sócio. Serve de
  /// primeiro acesso e de "esqueci-me"; a resposta é sempre a mesma.
  Future<String> pedirCodigo({String? email, int? nrSocio}) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/password/pedir', data: {
        'email': ?email,
        'nr_socio': ?nrSocio,
      }),
    );
    return (data['mensagem'] as String?) ?? 'Se a conta existir, segue um código.';
  }

  /// `POST /auth/password/repor`: define a password e abre a sessão. As outras
  /// sessões desta conta terminam.
  Future<void> confirmarCodigo({
    String? email,
    int? nrSocio,
    required String codigo,
    required String password,
  }) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/password/repor', data: {
        'email': ?email,
        'nr_socio': ?nrSocio,
        'codigo': codigo,
        'password': password,
      }),
    );
    await _abrir(data);
  }

  /// `POST /auth/password/alterar`: a resposta traz uma sessão nova; as outras
  /// terminam.
  Future<void> alterarPassword({required String actual, required String nova}) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/auth/password/alterar', data: {
        'password_atual': actual,
        'password_nova': nova,
      }),
    );
    await _abrir(data);
  }

  // ── A ficha de sócio ─────────────────────────────────────────────────────

  /// `POST /me/conta/socio`: pede o código, que segue para o **email da ficha**
  /// do sócio — e não para o da conta. É isso que prova a posse.
  Future<String> pedirSocio(int nrSocio) async {
    final data = await dadosDe(ref.read(dioContaProvider).post('/me/conta/socio', data: {'nr_socio': nrSocio}));
    return (data['mensagem'] as String?) ?? 'Enviámos um código para o email da sua ficha de sócio.';
  }

  /// `POST /me/conta/socio/confirmar`: a sessão volta já com sócio, e a zona
  /// privada abre.
  Future<void> confirmarSocio({required int nrSocio, required String codigo}) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).post('/me/conta/socio/confirmar', data: {'nr_socio': nrSocio, 'codigo': codigo}),
    );
    await _abrir(data);
  }

  /// `DELETE /me/conta/socio`: a conta fica sem ficha, mas continua a existir.
  Future<void> desassociarSocio(String password) async {
    final data = await dadosDe(
      ref.read(dioContaProvider).delete('/me/conta/socio', data: {'password': password}),
    );
    await _abrir(data);
  }

  // ── Sair e eliminar ──────────────────────────────────────────────────────

  /// `DELETE /me/conta`. Devolve a `mensagem` do servidor para mostrar depois;
  /// a sessão e as caches locais acabam logo.
  Future<String> eliminarConta(String password) async {
    final data = await dadosDe(ref.read(dioContaProvider).delete('/me/conta', data: {'password': password}));
    await ref.read(pushProvider.notifier).apagar();
    await ref.read(tokenStoreProvider).limpar();
    state = const SessaoAnonima();
    return (data['mensagem'] as String?) ?? 'A sua conta da app foi eliminada.';
  }

  /// `POST /auth/logout` — termina **só** a sessão deste aparelho. Entrar
  /// noutro telemóvel já não fecha esta.
  Future<void> sair() async {
    final store = ref.read(tokenStoreProvider);
    // Antes de limpar os tokens: o DELETE precisa da sessão que está a sair.
    await ref.read(pushProvider.notifier).apagar();
    try {
      await dadosDe(ref.read(dioContaProvider).post('/auth/logout', data: {}));
    } catch (_) {
      // Sem rede ou token já inválido: a sessão local acaba na mesma.
    }
    await store.limpar();
    state = const SessaoAnonima();
  }

  Future<void> _abrir(Map<String, dynamic> data) async {
    await ref.read(tokenStoreProvider).guardarSessao(data);
    if (data['conta'] is Map) {
      state = sessaoDaConta((data['conta'] as Map).cast<String, dynamic>());
    }
    // O token do aparelho só se entrega com sessão aberta (§4.15).
    await ref.read(pushProvider.notifier).registar();
  }

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Versões dos textos que o registo declara ter aceitado. Sobem quando os
/// textos mudarem — o servidor guarda-as com a conta.
const versaoTermos = '2026-09';
const versaoPrivacidade = '2026-09';
