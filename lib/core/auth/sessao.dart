import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/clientes.dart';
import '../api/envelope.dart';

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
    nrSocio: j['nr_socio'] as int,
    nomeCompleto: j['nome_completo'] as String,
    estado: j['estado'] as int,
    email: j['email'] as String?,
    fotoUrl: j['foto_url'] as String?,
  );
}

/// Quem está a usar a app. Hoje só há anónimo ou sócio; a conta com email de
/// não-sócio espera pelo pedido `2026-09-16-contas-nao-socios` no CISOC.
sealed class Sessao {
  const Sessao();
}

class SessaoAnonima extends Sessao {
  const SessaoAnonima();
}

class SessaoSocio extends Sessao {
  final SocioSessao socio;
  const SessaoSocio(this.socio);
}

final sessaoProvider = NotifierProvider<SessaoController, Sessao>(SessaoController.new);

class SessaoController extends Notifier<Sessao> {
  StreamSubscription<void>? _sub;

  @override
  Sessao build() {
    final store = ref.watch(tokenStoreProvider);
    _sub?.cancel();
    _sub = store.sessaoTerminada.listen((_) => state = const SessaoAnonima());
    ref.onDispose(() => _sub?.cancel());

    final socio = store.socio;
    return store.temSessao && socio != null ? SessaoSocio(SocioSessao.fromJson(socio)) : const SessaoAnonima();
  }

  Future<void> entrar({required int nrSocio, required String password}) async {
    final data = await dadosDe(
      ref.read(dioSocioProvider).post('/auth/login', data: {'nr_socio': nrSocio, 'password': password}),
    );
    await _abrir(data);
  }

  /// Primeiro acesso e "esqueci-me": pede o código. A resposta é sempre a
  /// mesma, exista ou não o sócio — devolve a `mensagem` para mostrar.
  Future<String> pedirCodigo(int nrSocio) async {
    final data = await dadosDe(ref.read(dioSocioProvider).post('/auth/recuperar', data: {'nr_socio': nrSocio}));
    return data['mensagem'] as String;
  }

  /// Confirma o código e define a password. O sócio fica logo autenticado.
  Future<void> confirmarCodigo({required int nrSocio, required String codigo, required String password}) async {
    final data = await dadosDe(
      ref
          .read(dioSocioProvider)
          .post('/auth/recuperar/confirmar', data: {'nr_socio': nrSocio, 'codigo': codigo, 'password': password}),
    );
    await _abrir(data);
  }

  /// `POST /auth/password`: a resposta traz tokens novos (o refresh anterior deixa
  /// de valer). Guardam-se no lugar dos antigos.
  Future<void> alterarPassword({required String actual, required String nova}) async {
    final data = await dadosDe(
      ref.read(dioSocioProvider).post('/auth/password', data: {'password_atual': actual, 'password_nova': nova}),
    );
    await _abrir(data);
  }

  /// `DELETE /me/conta`. Devolve a `mensagem` do servidor para mostrar depois;
  /// a sessão e as caches locais acabam logo.
  Future<String> eliminarConta(String password) async {
    final data = await dadosDe(ref.read(dioSocioProvider).delete('/me/conta', data: {'password': password}));
    await ref.read(tokenStoreProvider).limpar();
    state = const SessaoAnonima();
    return (data['mensagem'] as String?) ?? 'A sua conta da app foi eliminada.';
  }

  Future<void> sair() async {
    final store = ref.read(tokenStoreProvider);
    try {
      await dadosDe(ref.read(dioSocioProvider).post('/auth/logout', data: {}));
    } catch (_) {
      // Sem rede ou token já inválido: a sessão local acaba na mesma.
    }
    await store.limpar();
    state = const SessaoAnonima();
  }

  Future<void> _abrir(Map<String, dynamic> data) async {
    await ref.read(tokenStoreProvider).guardarLogin(data);
    // Ao mudar a password a sessão é a mesma: se não vier `socio`, mantém-se o actual.
    if (data['socio'] is Map) {
      state = SessaoSocio(SocioSessao.fromJson((data['socio'] as Map).cast<String, dynamic>()));
    }
  }
}
