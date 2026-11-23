import '../models/agendamento.dart';
import '../models/cliente.dart';
import '../models/consultorio.dart';
import '../models/notificacao.dart';
import '../models/servico.dart';

Future<void> latenciaMock() =>
    Future<void>.delayed(const Duration(milliseconds: 250));

/// Banco em memória usado com `--dart-define=USE_MOCK=true` (sem API).
/// Os agendamentos são gerados em relação a "hoje".
class MockDb {
  int _proximoId = 1000;
  int proximoId() => _proximoId++;

  String nomeUsuario = 'RGA';

  Consultorio consultorio = const Consultorio(
    nome: 'Clínica Exemplo',
    endereco: 'Rua das Flores, 123 · Centro',
    horarios: horariosPadrao,
  );

  final List<Servico> servicos = [
    const Servico(id: 1, nome: 'Consulta', duracaoMin: 45, valor: 150),
    const Servico(id: 2, nome: 'Retorno', duracaoMin: 30, valor: 80),
    const Servico(id: 3, nome: 'Avaliação inicial', duracaoMin: 60, valor: 200),
    const Servico(id: 4, nome: 'Limpeza', duracaoMin: 45, valor: 120),
  ];

  final List<Cliente> clientes = [
    Cliente(
      id: 1,
      nome: 'Ana Beatriz Souza',
      telefone: '5511987654321',
      email: 'ana.souza@email.com',
      desde: DateTime(2025, 3, 12),
    ),
    Cliente(
      id: 2,
      nome: 'André Lima',
      telefone: '5511976543210',
      email: 'andre.lima@email.com',
      desde: DateTime(2025, 5, 2),
    ),
    Cliente(
      id: 3,
      nome: 'Bruna Carvalho',
      telefone: '5511965432109',
      desde: DateTime(2025, 6, 18),
    ),
    Cliente(
      id: 4,
      nome: 'Bruno Alves',
      telefone: '5521984321098',
      email: 'bruno.alves@email.com',
      desde: DateTime(2025, 1, 7),
    ),
    Cliente(
      id: 5,
      nome: 'Camila Rocha',
      telefone: '5511954321987',
      desde: DateTime(2025, 8, 21),
    ),
    Cliente(
      id: 6,
      nome: 'Carlos Eduardo Pereira',
      telefone: '5531993210876',
      email: 'carlos.pereira@email.com',
      desde: DateTime(2024, 11, 30),
    ),
    Cliente(
      id: 7,
      nome: 'Daniela Martins',
      telefone: '5511943210765',
      desde: DateTime(2025, 2, 14),
    ),
    Cliente(
      id: 8,
      nome: 'Eduardo Ferreira',
      telefone: '5511932109654',
      email: 'edu.ferreira@email.com',
      desde: DateTime(2025, 9, 9),
    ),
    Cliente(
      id: 9,
      nome: 'Fernanda Gomes',
      telefone: '5521921098543',
      desde: DateTime(2024, 12, 5),
    ),
    Cliente(
      id: 10,
      nome: 'Gustavo Nunes',
      telefone: '5511910987432',
      email: 'gustavo.nunes@email.com',
      desde: DateTime(2025, 10, 1),
    ),
  ];

  final List<Notificacao> notificacoes = [
    Notificacao(
      id: 1,
      titulo: 'Agendamento confirmado',
      mensagem: 'Ana Beatriz confirmou presença.',
      dataHora: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    Notificacao(
      id: 2,
      titulo: 'Lembrete enviado',
      mensagem: 'Bruno Alves recebeu o lembrete pelo WhatsApp.',
      dataHora: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  late final List<Agendamento> agendamentos = _gerarAgendamentos();

  List<Agendamento> _gerarAgendamentos() {
    final hoje = DateTime.now();

    Agendamento ag(
      int cliente,
      int duracaoMin,
      int dias,
      int hora,
      int minuto, {
      StatusAgendamento status = StatusAgendamento.pendente,
      bool lembrete = false,
    }) {
      final inicio = DateTime(
        hoje.year,
        hoje.month,
        hoje.day + dias,
        hora,
        minuto,
      );
      return Agendamento(
        id: proximoId(),
        cliente: clientes[cliente],
        inicio: inicio,
        fim: inicio.add(Duration(minutes: duracaoMin)),
        profissional: nomeUsuario,
        usuarioId: 1,
        status: status,
        lembreteEnviado: lembrete,
      );
    }

    const ok = StatusAgendamento.confirmado;
    return [
      // Hoje
      ag(0, 45, 0, 9, 0, status: ok, lembrete: true),
      ag(3, 30, 0, 10, 30, lembrete: true),
      ag(4, 60, 0, 14, 0),
      ag(6, 45, 0, 15, 30, status: ok, lembrete: true),
      // Próximos dias
      ag(8, 45, 1, 9, 45),
      ag(9, 30, 1, 11, 15),
      ag(7, 60, 2, 10, 0, status: ok, lembrete: true),
      ag(2, 45, 2, 15, 0, status: StatusAgendamento.cancelado, lembrete: true),
      ag(1, 30, 3, 9, 0),
      // Histórico
      ag(0, 45, -20, 10, 0, status: ok),
      ag(0, 60, -75, 14, 0, status: ok),
      ag(2, 45, -10, 11, 0, status: ok),
      ag(3, 45, -35, 9, 0, status: ok),
      ag(3, 60, -90, 16, 0, status: ok),
      ag(5, 45, -100, 10, 30, status: ok),
      ag(6, 45, -50, 15, 0, status: ok),
      ag(7, 30, -8, 9, 45, status: ok),
      ag(8, 45, -120, 14, 30, status: ok),
      ag(9, 45, -3, 11, 15, status: ok),
      ag(1, 45, -70, 10, 0, status: ok),
      ag(4, 30, -28, 16, 0, status: ok),
    ];
  }
}
