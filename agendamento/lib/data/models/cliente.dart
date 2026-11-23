import '../../core/utils/formatters.dart';

class Cliente {
  const Cliente({
    required this.id,
    required this.nome,
    required this.telefone,
    this.email = '',
    this.desde,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    id: (json['id'] as num).toInt(),
    nome: json['nome'] as String? ?? '',
    telefone: json['telefone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    desde: DateTime.tryParse(json['clienteDesde'] as String? ?? ''),
  );

  final int id;
  final String nome;

  /// Como a API guarda (só dígitos, com 55). Use [telefoneFormatado] na tela.
  final String telefone;
  final String email;

  /// Data de cadastro (a API define ao criar).
  final DateTime? desde;

  String get iniciais => iniciaisDe(nome);
  String get telefoneFormatado => telefoneParaExibir(telefone);

  Cliente copyWith({String? nome, String? telefone, String? email}) => Cliente(
    id: id,
    nome: nome ?? this.nome,
    telefone: telefone ?? this.telefone,
    email: email ?? this.email,
    desde: desde,
  );
}
