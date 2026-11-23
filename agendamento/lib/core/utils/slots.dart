import '../../data/models/agendamento.dart';
import '../../data/models/consultorio.dart';
import '../../data/models/servico.dart';
import 'formatters.dart';

/// Horários livres de um dia para um serviço.
///
/// Os horários seguem o funcionamento do consultório, avançam de acordo com a
/// duração do serviço e ignoram horários passados e já ocupados.
/// Quando o backend tiver um endpoint de horários livres, é só trocar isto.
List<DateTime> calcularHorariosLivres({
  required DateTime dia,
  required Servico servico,
  required List<HorarioFuncionamento> horarios,
  required List<Agendamento> agendamentos,
  DateTime? agora,
}) {
  final funcionamento = horarios
      .where((h) => h.dias.contains(dia.weekday))
      .firstOrNull;
  if (funcionamento == null || servico.duracaoMin <= 0) return [];

  final referencia = agora ?? DateTime.now();
  final ocupados = agendamentos
      .where((a) => a.ativo && mesmoDia(a.inicio, dia))
      .toList();

  final livres = <DateTime>[];
  for (
    var m = funcionamento.abreMin;
    m + servico.duracaoMin <= funcionamento.fechaMin;
    m += servico.duracaoMin
  ) {
    final inicio = DateTime(dia.year, dia.month, dia.day, 0, m);
    final fim = inicio.add(Duration(minutes: servico.duracaoMin));
    if (!inicio.isAfter(referencia)) continue;
    final conflito = ocupados.any(
      (a) => inicio.isBefore(a.fim) && fim.isAfter(a.inicio),
    );
    if (!conflito) livres.add(inicio);
  }
  return livres;
}
