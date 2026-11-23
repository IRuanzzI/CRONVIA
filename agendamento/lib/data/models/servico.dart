/// Serviço do catálogo do consultório.
///
/// A API ainda não tem serviços: o catálogo fica no aparelho e serve para
/// definir a duração (e o valor de referência) ao agendar.
class Servico {
  const Servico({
    required this.id,
    required this.nome,
    required this.duracaoMin,
    required this.valor,
  });

  factory Servico.fromJson(Map<String, dynamic> json) => Servico(
    id: (json['id'] as num).toInt(),
    nome: json['nome'] as String? ?? '',
    duracaoMin: (json['duracaoMin'] as num?)?.toInt() ?? 30,
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
  );

  /// 0 = ainda não salvo.
  final int id;
  final String nome;
  final int duracaoMin;
  final double valor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'duracaoMin': duracaoMin,
    'valor': valor,
  };

  Servico copyWith({String? nome, int? duracaoMin, double? valor}) => Servico(
    id: id,
    nome: nome ?? this.nome,
    duracaoMin: duracaoMin ?? this.duracaoMin,
    valor: valor ?? this.valor,
  );
}
