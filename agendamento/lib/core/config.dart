import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// `--dart-define=USE_MOCK=true` roda o app com dados de exemplo, sem API.
  static const usarMock = bool.fromEnvironment('USE_MOCK');

  static const _apiUrlManual = String.fromEnvironment('API_URL');

  /// Endereço da API. Troque com `--dart-define=API_URL=http://192.168.0.10:8080`
  /// (necessário em celular físico: use o IP do computador na rede).
  static String get apiUrl {
    if (_apiUrlManual.isNotEmpty) return _apiUrlManual;
    // No emulador Android, o computador é 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
