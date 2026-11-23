import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/info_rows.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import '../../state/agenda_controller.dart';
import '../../state/clientes_controller.dart';

class ClienteDetalheScreen extends StatelessWidget {
  const ClienteDetalheScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final cliente = context.watch<ClientesController>().porId(id);
    final historico = context.watch<AgendaController>().historico(id);

    if (cliente == null) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ScreenHeader(titulo: 'Cliente'),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(titulo: 'Cliente'),
            const SizedBox(height: 20),
            Center(child: InitialsAvatar(nome: cliente.nome, size: 112)),
            const SizedBox(height: 16),
            Text(
              cliente.nome,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              cliente.desde != null
                  ? 'Cliente desde ${formatarData(cliente.desde!)}'
                  : historico.isEmpty
                  ? 'Nenhum atendimento ainda'
                  : '${historico.length} atendimento${historico.length == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/agendar?clienteId=$id'),
                    child: const Text('Agendar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/clientes/$id/editar'),
                    child: const Text('Editar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InfoRows(
              rows: [
                InfoRow('Telefone', cliente.telefoneFormatado),
                InfoRow('E-mail', cliente.email.isEmpty ? '—' : cliente.email),
              ],
            ),
            const SizedBox(height: 28),
            const SectionTitle('Histórico'),
            const SizedBox(height: 12),
            if (historico.isEmpty)
              const EstadoVazio(
                icone: Icons.history,
                texto: 'Nenhum atendimento ainda',
              )
            else
              for (final a in historico) ...[
                AppCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          formatarDiaMes(a.inicio),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atendimento · ${duracaoLabel(a.duracaoMin)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              a.profissional ?? formatarHora(a.inicio),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!a.ativo) StatusChip(status: a.status),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
