import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/clientes.dart';
import '../api/envelope.dart';
import '../auth/sessao.dart';
import 'firebase.dart';

/// Tópico a que toda a gente se inscreve, com sessão ou sem ela.
///
/// É o que o backoffice usa para falar com quem não tem conta — a app arranca
/// na zona pública e o `POST /dispositivos` exige token (§4.15).
const topicoTodos = 'all';

class EstadoPush {
  /// O Firebase arrancou nesta plataforma. `false` em iOS até haver app
  /// registada no projecto.
  final bool disponivel;

  /// O utilizador deixou a app mostrar notificações.
  final bool autorizado;

  /// Token do aparelho. Existe mesmo sem sessão (serve os tópicos).
  final String? token;

  /// O token já foi entregue ao servidor, para esta sessão.
  final bool registado;

  const EstadoPush({
    this.disponivel = false,
    this.autorizado = false,
    this.token,
    this.registado = false,
  });

  EstadoPush com({bool? disponivel, bool? autorizado, String? token, bool? registado}) => EstadoPush(
    disponivel: disponivel ?? this.disponivel,
    autorizado: autorizado ?? this.autorizado,
    token: token ?? this.token,
    registado: registado ?? this.registado,
  );
}

/// Corre num isolate próprio, sem a app. Não precisa de fazer nada: quando a
/// mensagem traz bloco `notification`, é o sistema que a mostra. Existe porque
/// o plugin exige um handler registado para entregar mensagens com a app fechada.
@pragma('vm:entry-point')
Future<void> mensagemEmSegundoPlano(RemoteMessage _) async {}

final pushProvider = NotifierProvider<PushController, EstadoPush>(PushController.new);

/// Liga o Firebase Messaging ao `/dispositivos` da API.
///
/// O token do aparelho é registado **depois do login** e apagado no logout,
/// senão o telemóvel continua a receber as notificações do sócio anterior — o
/// caso do telemóvel partilhado (§4.15).
class PushController extends Notifier<EstadoPush> {
  StreamSubscription<String>? _renovacoes;
  StreamSubscription<RemoteMessage>? _emPrimeiroPlano;

  /// Chamado quando chega uma mensagem com a app aberta. Quem liga isto é a
  /// interface, que sabe o que fazer com ela (avisar, recarregar a lista).
  void Function(RemoteMessage)? aoReceber;

  /// Chamado quando o utilizador toca numa notificação.
  void Function(RemoteMessage)? aoTocar;

  @override
  EstadoPush build() {
    ref.onDispose(() {
      _renovacoes?.cancel();
      _emPrimeiroPlano?.cancel();
    });
    return const EstadoPush();
  }

  /// Arranca o Firebase e apanha o token. Chamado uma vez, no arranque da app.
  ///
  /// Nunca rebenta: sem push a app funciona à mesma, só não recebe avisos.
  Future<void> arrancar() async {
    final opcoes = opcoesFirebase;
    if (opcoes == null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: opcoes);
      }
      FirebaseMessaging.onBackgroundMessage(mensagemEmSegundoPlano);
      final fm = FirebaseMessaging.instance;

      state = state.com(disponivel: true);
      await _lerPermissao(fm);

      // Toda a gente ouve o tópico geral, mesmo sem conta.
      await fm.subscribeToTopic(topicoTodos);

      state = state.com(token: await fm.getToken());
      // Só o princípio: chega para confirmar que há token, sem o deixar inteiro
      // no log — quem o tiver pode mandar notificações a este aparelho.
      if (kDebugMode) {
        final t = state.token;
        debugPrint('Push: token ${t == null ? 'em falta' : '${t.substring(0, 12)}… (${t.length} car.)'}');
      }
      _renovacoes = fm.onTokenRefresh.listen((t) {
        state = state.com(token: t, registado: false);
        registar();
      });

      _emPrimeiroPlano = FirebaseMessaging.onMessage.listen((m) => aoReceber?.call(m));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => aoTocar?.call(m));
      // A app estava fechada e abriu por causa de uma notificação.
      final inicial = await fm.getInitialMessage();
      if (inicial != null) aoTocar?.call(inicial);

      await registar();
    } catch (e) {
      // Chave restrita ao pacote da app publicada, aparelho sem Google Play,
      // projecto mal configurado: a app segue sem push.
      debugPrint('Push indisponível: $e');
    }
  }

  /// Lê a permissão que o aparelho já tem, sem pedir nada ao utilizador.
  Future<void> _lerPermissao(FirebaseMessaging fm) async {
    final r = await fm.getNotificationSettings();
    state = state.com(
      autorizado: r.authorizationStatus == AuthorizationStatus.authorized ||
          r.authorizationStatus == AuthorizationStatus.provisional,
    );
  }

  /// Pede a permissão de notificações. Só faz sentido quando o utilizador já
  /// percebe para que serve — depois de entrar, ou no ecrã das notificações.
  Future<bool> pedirPermissao() async {
    if (!state.disponivel) return false;
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      final ok = r.authorizationStatus == AuthorizationStatus.authorized ||
          r.authorizationStatus == AuthorizationStatus.provisional;
      state = state.com(autorizado: ok);
      if (ok) await registar();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// `POST /dispositivos`. Sem sessão não há nada a registar: o aparelho recebe
  /// pelos tópicos.
  Future<void> registar() async {
    final token = state.token;
    if (token == null || state.registado) return;
    if (ref.read(sessaoProvider) is! SessaoSocio) return;

    try {
      await dadosDe(
        ref.read(dioSocioProvider).post('/dispositivos', data: {'token': token, 'plataforma': _plataforma}),
      );
      state = state.com(registado: true);
    } catch (e) {
      // Fica por registar; tenta outra vez no próximo arranque ou login.
      debugPrint('Registo do dispositivo falhou: $e');
    }
  }

  /// `DELETE /dispositivos`, **antes** de a sessão acabar: o pedido leva o token
  /// da conta que está a sair.
  Future<void> apagar() async {
    final token = state.token;
    state = state.com(registado: false);
    if (token == null) return;
    try {
      await dadosDe(ref.read(dioSocioProvider).delete('/dispositivos', data: {'token': token}));
    } catch (_) {
      // Sem rede ou sessão já caída: não vale a pena insistir.
    }
  }

  /// O token vem do Firebase, que não corre nos testes.
  @visibleForTesting
  void tokenDeTeste(String? token) => state = state.com(disponivel: true, token: token, registado: false);

  static String get _plataforma {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }
}
