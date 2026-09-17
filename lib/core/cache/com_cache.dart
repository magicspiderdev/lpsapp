import '../api/api_exception.dart';
import 'cache_local.dart';

/// Dados para um ecrã, com a informação de frescura.
class Dados<T> {
  final T valor;
  final DateTime obtidoEm;

  /// Vieram do servidor agora. `false` = da cache (a actualizar, ou sem ligação).
  final bool actuais;

  /// A tentativa de actualizar falhou (tipicamente sem ligação).
  final ApiException? falhaAoActualizar;

  const Dados(this.valor, this.obtidoEm, {this.actuais = true, this.falhaAoActualizar});

  bool get desactualizados => !actuais && falhaAoActualizar != null;
}

/// Erros em que vale a pena mostrar a cache em vez do erro: o servidor não
/// respondeu ou falhou. Erros de negócio e de sessão passam para cima.
bool falhaDeServico(ApiException e) =>
    e.erro == 'sem_ligacao' ||
    e.erro == 'erro_interno' ||
    e.erro == 'resposta_invalida' ||
    (e.httpStatus != null && e.httpStatus! >= 500);

/// Mostra primeiro o que está guardado e depois o que vem do servidor.
///
/// 1. Se houver cache, emite-a logo (`actuais: false`).
/// 2. Pede ao servidor; com sucesso guarda e emite (`actuais: true`).
/// 3. Se o serviço falhar e havia cache, volta a emiti-la com `falhaAoActualizar`.
///    Sem cache, o erro sobe.
Stream<Dados<T>> comCache<T>({
  required CacheLocal cache,
  required Ambito ambito,
  required String chave,
  required Future<Map<String, dynamic>> Function() pedido,
  required T Function(Map<String, dynamic>) ler,
}) async* {
  final guardado = await cache.ler(ambito, chave);
  T? valorGuardado;
  if (guardado != null) {
    try {
      valorGuardado = ler(guardado.dados);
      yield Dados(valorGuardado as T, guardado.obtidoEm, actuais: false);
    } catch (_) {
      valorGuardado = null; // formato antigo ou corrompido: ignora
    }
  }

  try {
    final dados = await pedido();
    final valor = ler(dados);
    await cache.guardar(ambito, chave, dados);
    yield Dados(valor, DateTime.now());
  } on ApiException catch (e) {
    if (guardado != null && valorGuardado != null && falhaDeServico(e)) {
      yield Dados(valorGuardado as T, guardado.obtidoEm, actuais: false, falhaAoActualizar: e);
    } else {
      rethrow;
    }
  }
}
