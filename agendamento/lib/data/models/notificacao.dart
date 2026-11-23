class Notificacao {
  const Notificacao({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.dataHora,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) => Notificacao(
    id: (json['id'] as num).toInt(),
    titulo: json['titulo'] as String? ?? '',
    mensagem: json['mensagem'] as String? ?? '',
    dataHora:
        DateTime.tryParse(json['dataHora'] as String? ?? '') ?? DateTime.now(),
  );

  final int id;
  final String titulo;
  final String mensagem;
  final DateTime dataHora;
}
