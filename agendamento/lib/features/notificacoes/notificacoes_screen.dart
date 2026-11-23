import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/notificacao.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/notificacoes_controller.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificacoesController>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificacoes = context.watch<NotificacoesController>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notificacoes.carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const ScreenHeader(titulo: 'Notificações'),
              const SizedBox(height: 20),
              if (notificacoes.carregando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (notificacoes.erro != null)
                EstadoVazio(
                  icone: Icons.cloud_off_outlined,
                  texto: notificacoes.erro!,
                  onAcao: notificacoes.carregar,
                )
              else if (notificacoes.notificacoes.isEmpty)
                const EstadoVazio(
                  icone: Icons.notifications_none_rounded,
                  texto: 'Nenhuma novidade por enquanto',
                )
              else
                for (final notificacao in notificacoes.notificacoes) ...[
                  _Evento(notificacao: notificacao),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento({required this.notificacao});

  final Notificacao notificacao;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificacao.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notificacao.mensagem,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatarDiaMes(notificacao.dataHora)} às ${formatarHora(notificacao.dataHora)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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
