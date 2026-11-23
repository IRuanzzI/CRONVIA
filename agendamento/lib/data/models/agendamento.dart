import 'cliente.dart';

/// Status do agendamento na API.
///
/// `CONFIRMADO`, `CANCELADO` e `FINALIZADO` aparecem no código da API; o
/// valor inicial ([statusInicial]) ainda não está definido lá.
enum StatusAgendamento {
  pendente('PENDENTE', 'Pendente'),
  confirmado('CONFIRMADO', 'Confirmado'),
  cancelado('CANCELADO', 'Cancelado'),
  finalizado('FINALIZADO', 'Finalizado');

  const StatusAgendamento(this.api, this.label);

  final String api;
  final String label;

  /// Status enviado ao criar um agendamento.
  static const statusInicial = pendente;

  static StatusAgendamento fromApi(String? valor) => values.firstWhere(
    (s) => s.api == valor?.toUpperCase(),
    orElse: () => pendente,
  );
}

class Agendamento {
  const Agendamento({
    required this.id,
    required this.cliente,
    required this.inicio,
    required this.fim,
    this.profissional,
    this.usuarioId,
    this.status = StatusAgendamento.pendente,
    this.lembreteEnviado = false,
  });

  /// Lê o JSON da API (entidade `Agendamento`).
  factory Agendamento.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'];
    final usuario = json['usuario'];
    final inicio = DateTime.parse(json['data_hora_inicio'] as String);
    final fimTexto = json['data_hora_final'] as String?;
    return Agendamento(
      id: (json['id'] as num).toInt(),
      cliente: cliente is Map<String, dynamic>
          ? Cliente.fromJson(cliente)
          : const Cliente(id: 0, nome: 'Cliente removido', telefone: ''),
      usuarioId: usuario is Map ? (usuario['id'] as num?)?.toInt() : null,
      profissional: usuario is Map ? usuario['nome'] as String? : null,
      inicio: inicio,
      fim: fimTexto == null
          ? inicio.add(const Duration(minutes: 30))
          : DateTime.parse(fimTexto),
      status: StatusAgendamento.fromApi(json['status'] as String?),
      lembreteEnviado: json['lembreteEnviado'] as bool? ?? false,
    );
  }

  final int id;
  final Cliente cliente;
  final DateTime inicio;
  final DateTime fim;

  /// Nome do usuário que criou (a API só devolve se o `usuario` foi salvo).
  final String? profissional;
  final int? usuarioId;
  final StatusAgendamento status;
  final bool lembreteEnviado;

  bool get ativo => status != StatusAgendamento.cancelado;
  int get duracaoMin => fim.difference(inicio).inMinutes;

  Agendamento copyWith({Cliente? cliente, StatusAgendamento? status}) =>
      Agendamento(
        id: id,
        cliente: cliente ?? this.cliente,
        inicio: inicio,
        fim: fim,
        profissional: profissional,
        usuarioId: usuarioId,
        status: status ?? this.status,
        lembreteEnviado: lembreteEnviado,
      );
}
