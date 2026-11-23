import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/agendamento.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/day_strip.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/status_chip.dart';
import '../../state/agenda_controller.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agenda = context.watch<AgendaController>();
    final dia = agenda.dataSelecionada;
    final lista = agenda.doDia(dia);
    final agora = DateTime.now();
    // Destaca o próximo atendimento do dia (só quando o dia é hoje).
    final proximo = mesmoDia(dia, agora)
        ? lista.where((a) => a.ativo && a.fim.isAfter(agora)).firstOrNull
        : null;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo agendamento',
        onPressed: () => context.push(
          '/agendar?data=${dia.toIso8601String().substring(0, 10)}',
        ),
        child: const Icon(Icons.add, size: 30),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatarMesAno(dia),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Agenda',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.chevron_left,
                    size: 44,
                    tooltip: 'Semana anterior',
                    onPressed: () => agenda.selecionarData(somarDias(dia, -7)),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.chevron_right,
                    size: 44,
                    tooltip: 'Próxima semana',
                    onPressed: () => agenda.selecionarData(somarDias(dia, 7)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DayStrip(selecionado: dia, onSelect: agenda.selecionarData),
              const SizedBox(height: 16),
              Expanded(
                child: lista.isEmpty
                    ? EstadoVazio(
                        icone: agenda.carregando
                            ? Icons.hourglass_empty
                            : agenda.erro != null
                            ? Icons.cloud_off_outlined
                            : Icons.event_available_outlined,
                        texto: agenda.carregando
                            ? 'Carregando agenda...'
                            : agenda.erro ?? 'Nenhum agendamento neste dia',
                        onAcao: agenda.erro != null && !agenda.carregando
                            ? agenda.carregar
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: agenda.carregar,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _CardAgendamento(
                            agendamento: lista[i],
                            destaque: lista[i].id == proximo?.id,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAgendamento extends StatelessWidget {
  const _CardAgendamento({required this.agendamento, required this.destaque});

  final Agendamento agendamento;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final cancelado = !a.ativo;
    final opacidade = cancelado ? 0.55 : 1.0;

    return AppCard(
      color: destaque ? AppColors.primaryContainer : null,
      borderColor: destaque ? AppColors.primary.withValues(alpha: .35) : null,
      onTap: () => _abrirDetalhes(context, a),
      child: Opacity(
        opacity: opacidade,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                formatarHora(a.inicio),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.cliente.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      decoration: cancelado ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Atendimento · ${duracaoLabel(a.duracaoMin)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: a.status),
          ],
        ),
      ),
    );
  }
}

void _abrirDetalhes(BuildContext context, Agendamento a) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DetalhesSheet(agendamento: a),
  );
}

class _DetalhesSheet extends StatelessWidget {
  const _DetalhesSheet({required this.agendamento});

  final Agendamento agendamento;

  Future<void> _executar(
    BuildContext context,
    Future<void> Function() acao,
    String sucesso,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await acao();
      navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(sucesso)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDeErro(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final agenda = context.read<AgendaController>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.cliente.nome,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Atendimento · ${duracaoLabel(a.duracaoMin)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _Linha(
              icone: Icons.schedule,
              texto:
                  '${formatarData(a.inicio)} · ${formatarHora(a.inicio)} às ${formatarHora(a.fim)}',
            ),
            if (a.profissional != null)
              _Linha(icone: Icons.person_outline, texto: a.profissional!),
            _Linha(
              icone: Icons.phone_outlined,
              texto: a.cliente.telefoneFormatado,
            ),
            if (a.ativo)
              _Linha(
                icone: Icons.chat_bubble_outline,
                texto: a.lembreteEnviado
                    ? 'Lembrete enviado por WhatsApp'
                    : 'Lembrete automático no WhatsApp 24h antes',
                cor: AppColors.primary,
              ),
            const SizedBox(height: 20),
            if (a.status != StatusAgendamento.confirmado && a.ativo) ...[
              FilledButton(
                onPressed: () => _executar(
                  context,
                  () => agenda.definirStatus(
                    a.id,
                    StatusAgendamento.confirmado,
                  ),
                  'Agendamento confirmado.',
                ),
                child: const Text('Confirmar agendamento'),
              ),
              const SizedBox(height: 10),
            ],
            if (!a.ativo) ...[
              FilledButton(
                onPressed: () => _executar(
                  context,
                  () => agenda.definirStatus(a.id, StatusAgendamento.pendente),
                  'Agendamento reativado.',
                ),
                child: const Text('Reativar agendamento'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/clientes/${a.cliente.id}');
              },
              child: const Text('Ver cliente'),
            ),
            if (a.ativo) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  final sim = await confirmar(
                    context,
                    titulo: 'Cancelar agendamento?',
                    mensagem:
                        'O horário de ${formatarHora(a.inicio)} de ${a.cliente.nome} ficará livre.',
                    confirmarLabel: 'Cancelar agendamento',
                    destrutivo: true,
                  );
                  if (!sim || !context.mounted) return;
                  await _executar(
                    context,
                    () => agenda.definirStatus(
                      a.id,
                      StatusAgendamento.cancelado,
                    ),
                    'Agendamento cancelado.',
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Cancelar agendamento'),
              ),
            ],
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () async {
                  final sim = await confirmar(
                    context,
                    titulo: 'Excluir agendamento?',
                    mensagem: 'Esta ação não pode ser desfeita.',
                    confirmarLabel: 'Excluir',
                    destrutivo: true,
                  );
                  if (!sim || !context.mounted) return;
                  await _executar(
                    context,
                    () => agenda.excluir(a.id),
                    'Agendamento excluído.',
                  );
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Excluir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.texto, this.cor});

  final IconData icone;
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icone, size: 20, color: cor ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 15,
                color: cor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
