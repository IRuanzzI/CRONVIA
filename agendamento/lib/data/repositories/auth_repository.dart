import '../../core/errors.dart';
import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/usuario.dart';

abstract class AuthRepository {
  Future<Sessao> login(String email, String senha);
  Future<void> alterarSenha({required String atual, required String nova});
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<Sessao> login(String email, String senha) async {
    final dynamic json;
    try {
      json = await _api.post(
        '/api/v1/auth/login',
        corpo: {'email': email, 'senha': senha},
      );
    } on ApiException catch (e) {
      // A API responde 401 para e-mail/senha incorretos.
      if (const {400, 401}.contains(e.statusCode)) {
        throw const AppException('E-mail ou senha incorretos.');
      }
      // 403 (empresa suspensa/vencida) e 429 (muitas tentativas) já trazem a
      // mensagem do servidor; qualquer outro erro segue como veio.
      rethrow;
    }

    if (json is! Map || json['token'] is! String) {
      throw const AppException(
        'Resposta de login inválida. Confira o AuthResponse da API.',
      );
    }

    return Sessao(
      token: json['token'] as String,
      usuario: Usuario(
        id: ((json['usuarioId'] ?? json['id']) as num?)?.toInt(),
        nome: json['nome'] as String? ?? '',
        email: email,
        role: json['role'] as String? ?? '',
        tenantId: (json['tenantId'] as num?)?.toInt() ?? 0,
        empresa: json['tenant'] as String? ?? '',
        precisaTrocarSenha: json['precisaTrocarSenha'] as bool? ?? false,
      ),
    );
  }

  @override
  Future<void> alterarSenha({required String atual, required String nova}) async {
    await _api.post(
      '/api/v1/auth/alterar-senha',
      corpo: {'senhaAtual': atual, 'novaSenha': nova},
    );
  }
}

/// Modo `USE_MOCK`: aceita qualquer e-mail válido com senha de 4+ caracteres.
/// Para demonstrar os perfis: e-mail com "master" entra como MASTER e e-mail
/// com "troca" cai na troca obrigatória de senha.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._db);

  final MockDb _db;

  @override
  Future<Sessao> login(String email, String senha) async {
    await latenciaMock();
    if (senha.length < 4) throw const AppException('E-mail ou senha incorretos.');
    final master = email.toLowerCase().contains('master');
    return Sessao(
      token: 'mock-token',
      usuario: Usuario(
        id: 1,
        nome: _db.nomeUsuario,
        email: email,
        role: master ? 'MASTER' : 'ADMIN',
        tenantId: 1,
        empresa: master ? 'SaaS do Ruan' : _db.consultorio.nome,
        precisaTrocarSenha: email.toLowerCase().contains('troca'),
      ),
    );
  }

  @override
  Future<void> alterarSenha({required String atual, required String nova}) async {
    await latenciaMock();
    if (atual.length < 4) throw const AppException('A senha atual está incorreta.');
  }
}
