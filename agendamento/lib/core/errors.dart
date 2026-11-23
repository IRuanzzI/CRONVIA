/// Erro com mensagem pronta para mostrar ao usuário.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Erro devolvido pela API (com o status HTTP).
class ApiException extends AppException {
  const ApiException(super.message, {required this.statusCode});

  final int statusCode;
}

String mensagemDeErro(Object erro) =>
    erro is AppException ? erro.message : 'Algo deu errado. Tente novamente.';
