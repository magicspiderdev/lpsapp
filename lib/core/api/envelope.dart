import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Faz o pedido e devolve o `data` de uma resposta `status: success`.
/// Qualquer outra coisa sai como [ApiException].
Future<Map<String, dynamic>> dadosDe(Future<Response<dynamic>> pedido) async {
  try {
    final r = await pedido;
    final corpo = r.data;
    if (corpo is Map && corpo['status'] == 'success') {
      return (corpo['data'] as Map).cast<String, dynamic>();
    }
    if (corpo is Map && corpo['erro'] is String) {
      throw ApiException(
        httpStatus: r.statusCode,
        erro: corpo['erro'] as String,
        message: (corpo['message'] as String?) ?? 'Ocorreu um erro.',
        dados: corpo.cast<String, dynamic>(),
      );
    }
    throw ApiException(
      httpStatus: r.statusCode,
      erro: 'resposta_invalida',
      message: 'O serviço devolveu uma resposta inesperada.',
    );
  } on DioException catch (e) {
    throw ApiException.deDio(e);
  }
}
