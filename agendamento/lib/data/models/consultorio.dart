import '../../core/utils/formatters.dart';

class HorarioFuncionamento {
  const HorarioFuncionamento({
    required this.rotulo,
    required this.dias,
    required this.abreMin,
    required this.fechaMin,
  });

  factory HorarioFuncionamento.fromJson(Map<String, dynamic> json) =>
      HorarioFuncionamento(
        rotulo: json['rotulo'] as String? ?? '',
        dias: [for (final d in json['dias'] as List? ?? []) (d as num).toInt()],
        abreMin: (json['abreMin'] as num).toInt(),
        fechaMin: (json['fechaMin'] as num).toInt(),
      );

  final String rotulo;

  /// Dias da semana no padrão do DateTime (1 = segunda ... 7 = domingo).
  final List<int> dias;
  final int abreMin;
  final int fechaMin;

  String get faixa =>
      '${minutosParaHora(abreMin)} – ${minutosParaHora(fechaMin)}';

  Map<String, dynamic> toJson() => {
    'rotulo': rotulo,
    'dias': dias,
    'abreMin': abreMin,
    'fechaMin': fechaMin,
  };

  HorarioFuncionamento copyWith({int? abreMin, int? fechaMin}) =>
      HorarioFuncionamento(
        rotulo: rotulo,
        dias: dias,
        abreMin: abreMin ?? this.abreMin,
        fechaMin: fechaMin ?? this.fechaMin,
      );
}

/// Dados do consultório. O nome vem da empresa (tenant) no login; endereço e
/// horários ficam no aparelho até a API ter onde guardá-los.
class Consultorio {
  const Consultorio({
    required this.nome,
    required this.endereco,
    required this.horarios,
  });

  final String nome;
  final String endereco;
  final List<HorarioFuncionamento> horarios;

  Consultorio copyWith({
    String? nome,
    String? endereco,
    List<HorarioFuncionamento>? horarios,
  }) => Consultorio(
    nome: nome ?? this.nome,
    endereco: endereco ?? this.endereco,
    horarios: horarios ?? this.horarios,
  );
}

const horariosPadrao = [
  HorarioFuncionamento(
    rotulo: 'Seg a Sex',
    dias: [1, 2, 3, 4, 5],
    abreMin: 9 * 60,
    fechaMin: 18 * 60,
  ),
  HorarioFuncionamento(
    rotulo: 'Sábado',
    dias: [6],
    abreMin: 9 * 60,
    fechaMin: 13 * 60,
  ),
];
