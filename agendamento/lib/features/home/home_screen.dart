import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_title.dart';
import '../../state/agenda_controller.dart';
import '../../state/auth_controller.dart';
import '../../state/consultorio_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthController>().usuario;
    final agenda = context.watch<AgendaController>();
    final consultorio = context.watch<ConsultorioController>().consultorio;
    final proximos = agenda.proximosHoje();
    final nome = usuario?.nome ?? '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                InitialsAvatar(nome: nome, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bem-vindo,',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notificações',
                  onPressed: () => context.push('/notificacoes'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (consultorio.nome.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        consultorio.nome,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            AppCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agendamentos de hoje',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${agenda.totalHoje}',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      agenda.selecionarData(DateTime.now());
                      context.go('/agenda');
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Ver agenda'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Acesso rápido'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _Atalho(
                  icone: Icons.add,
                  texto: 'Novo agendamento',
                  destaque: true,
                  onTap: () => context.push('/agendar'),
                ),
                _Atalho(
                  icone: Icons.people_outline,
                  texto: 'Clientes',
                  onTap: () => context.go('/clientes'),
                ),
                _Atalho(
                  icone: Icons.home_work_outlined,
                  texto: 'Consultório',
                  onTap: () => context.push('/consultorio'),
                ),
                _Atalho(
                  icone: Icons.settings_outlined,
                  texto: 'Configurações',
                  onTap: () => context.go('/ajustes'),
                ),
              ],
            ),
            if (proximos.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionTitle('Próximos hoje'),
              const SizedBox(height: 12),
              for (final a in proximos) ...[
                AppCard(
                  onTap: () {
                    agenda.selecionarData(a.inicio);
                    context.go('/agenda');
                  },
                  child: Row(
                    children: [
                      Text(
                        formatarHora(a.inicio),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.cliente.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Atendimento · ${duracaoLabel(a.duracaoMin)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({
    required this.icone,
    required this.texto,
    required this.onTap,
    this.destaque = false,
  });

  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final corTexto = destaque ? AppColors.onPrimary : AppColors.textPrimary;
    return AppCard(
      onTap: onTap,
      color: destaque ? AppColors.primary : null,
      borderColor: destaque ? AppColors.primary : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 26,
            color: destaque ? AppColors.onPrimary : AppColors.primary,
          ),
          const Spacer(),
          Text(
            texto,
            style: TextStyle(
              color: corTexto,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
