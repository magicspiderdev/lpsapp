import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Há ligação ao servidor?
///
/// O sistema diz se há rede; os pedidos dizem se o servidor responde (Wi-Fi sem
/// internet conta como sem ligação). Começa optimista.
final ligacaoProvider = NotifierProvider<LigacaoController, bool>(LigacaoController.new);

class LigacaoController extends Notifier<bool> {
  @override
  bool build() {
    final sub = Connectivity().onConnectivityChanged.listen(
      (r) => state = !r.every((e) => e == ConnectivityResult.none),
      onError: (_) {},
    );
    ref.onDispose(sub.cancel);
    return true;
  }

  void pedidoFalhouPorRede() => state = false;
  void pedidoRespondeu() => state = true;
}

/// Actualiza [ligacaoProvider] com o resultado de cada pedido.
class LigacaoInterceptor extends Interceptor {
  LigacaoInterceptor(this._ref);

  final Ref _ref;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _ref.read(ligacaoProvider.notifier).pedidoRespondeu();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final ligacao = _ref.read(ligacaoProvider.notifier);
    switch (err.type) {
      case DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout:
        ligacao.pedidoFalhouPorRede();
      case _ when err.response != null:
        ligacao.pedidoRespondeu(); // o servidor respondeu, ainda que com erro
      case _:
        break;
    }
    handler.next(err);
  }
}
