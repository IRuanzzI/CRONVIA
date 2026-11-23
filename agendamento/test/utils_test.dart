import 'package:agendamento/core/utils/formatters.dart';
import 'package:agendamento/core/utils/slots.dart';
import 'package:agendamento/data/models/agendamento.dart';
import 'package:agendamento/data/models/cliente.dart';
import 'package:agendamento/data/models/consultorio.dart';
import 'package:agendamento/data/models/servico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const consulta = Servico(id: 1, nome: 'Consulta', duracaoMin: 45, valor: 150);
  const horarios = [
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
  // Terça, 3 de novembro de 2026.
  final terca = DateTime(2026, 11, 3);
  final cedo = DateTime(2026, 11, 3, 6);

  Agendamento ocupado(int hora, int minuto, {StatusAgendamento? status}) {
    final inicio = DateTime(2026, 11, 3, hora, minuto);
    return Agendamento(
      id: 1,
      cliente: const Cliente(id: 1, nome: 'Ana', telefone: ''),
      profissional: 'Ruan',
      inicio: inicio,
      fim: inicio.add(const Duration(minutes: 45)),
      status: status ?? StatusAgendamento.pendente,
    );
  }

  group('calcularHorariosLivres', () {
    test('avança pela duração do serviço dentro do funcionamento', () {
      final slots = calcularHorariosLivres(
        dia: terca,
        servico: consulta,
        horarios: horarios,
        agendamentos: [],
        agora: cedo,
      );
      expect(slots.length, 12);
      expect(formatarHora(slots.first), '09:00');
      expect(formatarHora(slots[1]), '09:45');
      expect(formatarHora(slots.last), '17:15');
    });

    test('remove horários ocupados, mas não os cancelados', () {
      final slots = calcularHorariosLivres(
        dia: terca,
        servico: consulta,
        horarios: horarios,
        agendamentos: [
          ocupado(9, 45),
          ocupado(10, 30, status: StatusAgendamento.cancelado),
        ],
        agora: cedo,
      );
      final horas = slots.map(formatarHora).toList();
      expect(horas, isNot(contains('09:45')));
      expect(horas, contains('09:00'));
      expect(horas, contains('10:30'));
    });

    test('ignora horários que já passaram', () {
      final slots = calcularHorariosLivres(
        dia: terca,
        servico: consulta,
        horarios: horarios,
        agendamentos: [],
        agora: DateTime(2026, 11, 3, 12, 0),
      );
      expect(slots.every((s) => s.isAfter(DateTime(2026, 11, 3, 12))), isTrue);
    });

    test('domingo não tem horários', () {
      final slots = calcularHorariosLivres(
        dia: DateTime(2026, 11, 8),
        servico: consulta,
        horarios: horarios,
        agendamentos: [],
        agora: cedo,
      );
      expect(slots, isEmpty);
    });

    test('sábado fecha mais cedo', () {
      final slots = calcularHorariosLivres(
        dia: DateTime(2026, 11, 7),
        servico: consulta,
        horarios: horarios,
        agendamentos: [],
        agora: cedo,
      );
      expect(formatarHora(slots.last), '12:00');
    });
  });

  group('formatters', () {
    test('iniciais', () {
      expect(iniciaisDe('Nome do Cliente'), 'NC');
      expect(iniciaisDe('Ruan Pablo'), 'RP');
      expect(iniciaisDe('Ana'), 'A');
    });

    test('duração', () {
      expect(duracaoLabel(45), '45 min');
      expect(duracaoLabel(60), '1h');
      expect(duracaoLabel(90), '1h30');
    });

    test('lerMoeda aceita vírgula e ponto', () {
      expect(lerMoeda('150'), 150);
      expect(lerMoeda('150,50'), 150.5);
      expect(lerMoeda('1.250,00'), 1250);
      expect(lerMoeda(''), isNull);
    });

    test('formato ISO da API', () {
      expect(paraIsoApi(DateTime(2026, 11, 3, 9, 5)), '2026-11-03T09:05:00');
    });

    test('semana começa na segunda', () {
      expect(inicioDaSemana(DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
    });

    test('máscara de telefone', () {
      final f = TelefoneInputFormatter();
      String aplicar(String t) => f
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t))
          .text;
      expect(aplicar('11912345678'), '(11) 91234-5678');
      expect(aplicar('1133334444'), '(11) 3333-4444');
    });
  });
}
