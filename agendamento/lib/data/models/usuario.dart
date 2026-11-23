class Usuario {
  const Usuario({
    required this.nome,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.empresa,
    this.id,
    this.precisaTrocarSenha = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: (json['id'] as num?)?.toInt(),
    nome: json['nome'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? '',
    tenantId: (json['tenantId'] as num?)?.toInt() ?? 0,
    empresa: json['empresa'] as String? ?? '',
    precisaTrocarSenha: json['precisaTrocarSenha'] as bool? ?? false,
  );

  /// A API devolve o id do usuário no login.
  final int? id;
  final String nome;
  final String email;

  /// MASTER, ADMIN ou USUARIO.
  final String role;
  final int tenantId;

  /// Nome fantasia da empresa (tenant).
  final String empresa;

  /// Senha provisória (cadastro ou redefinição): precisa ser trocada já.
  final bool precisaTrocarSenha;

  bool get ehMaster => role == 'MASTER';
  bool get ehAdmin => role == 'ADMIN' || role == 'MASTER';

  Usuario copyWith({bool? precisaTrocarSenha}) => Usuario(
    id: id,
    nome: nome,
    email: email,
    role: role,
    tenantId: tenantId,
    empresa: empresa,
    precisaTrocarSenha: precisaTrocarSenha ?? this.precisaTrocarSenha,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'email': email,
    'role': role,
    'tenantId': tenantId,
    'empresa': empresa,
    'precisaTrocarSenha': precisaTrocarSenha,
  };
}

/// Usuário logado + token JWT.
class Sessao {
  const Sessao({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}
