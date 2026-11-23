import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/agendamento.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/status_chip.dart';
import '../../state/agenda_controller.dart';

/// Mostra o que o WhatsApp automático fez: respostas dos clientes
/// (confirmou/cancelou) e lembretes enviados.
class NotificacoesScreen extends StatelessWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agenda = context.watch<AgendaController>();
    final limite = DateTime.now().subtract(const Duration(days: 7));
    final eventos = agenda.agendamentos
        .where(
          (a) =>
              a.inicio.isAfter(limite) &&
              (a.status != StatusAgendamento.pendente || a.lembreteEnviado),
        )
        .toList()
      ..sort((a, b) => b.inicio.compareTo(a.inicio));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(titulo: 'Notificações'),
            const SizedBox(height: 20),
            if (eventos.isEmpty)
              const EstadoVazio(
                icone: Icons.notifications_none_rounded,
                texto: 'Nenhuma novidade por enquanto',
              )
            else
              for (final a in eventos) ...[
                _Evento(agendamento: a),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento({required this.agendamento});

  final Agendamento agendamento;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final (icone, titulo, aviso) = switch (a.status) {
      StatusAgendamento.confirmado => (
        Icons.check_circle_outline,
        '${a.cliente.nome} confirmou presença',
        null,
      ),
      StatusAgendamento.cancelado => (
        Icons.cancel_outlined,
        '${a.cliente.nome} cancelou',
        null,
      ),
      StatusAgendamento.finalizado => (
        Icons.task_alt_outlined,
        'Atendimento de ${a.cliente.nome} finalizado',
        null,
      ),
      StatusAgendamento.pendente => (
        Icons.chat_bubble_outline,
        'Lembrete enviado para ${a.cliente.nome}',
        'Aguardando resposta',
      ),
    };
    final cor = corDoStatus(a.status);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatarDiaMes(a.inicio)} às ${formatarHora(a.inicio)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (aviso != null)
                  Text(
                    aviso,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
