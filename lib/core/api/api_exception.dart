import 'package:dio/dio.dart';

/// Erro da API já normalizado a partir do envelope
/// `{ "status": "error", "erro": "...", "message": "..." }`.
///
/// `erro` é estável e serve para lógica; `message` vem pronta a mostrar.
class ApiException implements Exception {
  final int? httpStatus;
  final String erro;
  final String message;

  /// O corpo completo, para campos extra como `tentativas_restantes`.
  final Map<String, dynamic> dados;

  const ApiException({
    required this.erro,
    required this.message,
    this.httpStatus,
    this.dados = const {},
  });

  factory ApiException.deDio(DioException e) {
    final corpo = e.response?.data;
    if (corpo is Map && corpo['erro'] is String) {
      return ApiException(
        httpStatus: e.response?.statusCode,
        erro: corpo['erro'] as String,
        message: (corpo['message'] as String?) ?? 'Ocorreu um erro.',
        dados: corpo.cast<String, dynamic>(),
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        const ApiException(
          erro: 'sem_ligacao',
          message: 'Sem ligação ao servidor. Verifique a internet e tente novamente.',
        ),
      _ => ApiException(
          httpStatus: e.response?.statusCode,
          erro: 'erro_interno',
          message: 'O serviço está indisponível. Tente novamente daqui a pouco.',
        ),
    };
  }

  int? get tentativasRestantes => dados['tentativas_restantes'] as int?;

  @override
  String toString() => 'ApiException($httpStatus $erro)';
}
