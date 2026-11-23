import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../state/auth_controller.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final usuario = auth.usuario;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Ajustes',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            AppCard(
              radius: 24,
              onTap: () => context.push('/perfil'),
              child: Row(
                children: [
                  InitialsAvatar(nome: usuario?.nome ?? '', size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario?.nome ?? '',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          usuario?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Grupo(
              titulo: 'Conta',
              itens: [
                _Item(
                  icone: Icons.people_outline,
                  texto: 'Meu perfil',
                  onTap: () => context.push('/perfil'),
                ),
                _Item(
                  icone: Icons.lock_outline,
                  texto: 'Alterar senha',
                  onTap: () => context.push('/senha'),
                ),
              ],
            ),
            // O MASTER não tem consultório nem WhatsApp próprios: ele gerencia
            // os dos clientes pelo painel de empresas.
            if (!(usuario?.ehMaster ?? false))
              _Grupo(
                titulo: 'Empresa',
                itens: [
                  _Item(
                    icone: Icons.home_work_outlined,
                    texto: 'Consultório',
                    onTap: () => context.push('/consultorio'),
                  ),
                  _Item(
                    icone: Icons.calendar_today_outlined,
                    texto: 'Horários e serviços',
                    onTap: () => context.push('/consultorio'),
                  ),
                  if (usuario?.ehAdmin ?? false)
                    _Item(
                      icone: Icons.chat_outlined,
                      texto: 'WhatsApp',
                      onTap: () => context.push('/whatsapp'),
                    ),
                ],
              ),
            _Grupo(
              titulo: 'Preferências',
              itens: [
                _Item(
                  icone: Icons.notifications_none_rounded,
                  texto: 'Notificações',
                  onTap: () =>
                      auth.definirNotificacoes(!auth.notificacoesAtivas),
                  trailing: Switch(
                    value: auth.notificacoesAtivas,
                    onChanged: auth.definirNotificacoes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                final sim = await confirmar(
                  context,
                  titulo: 'Sair da conta?',
                  mensagem: 'Você precisará entrar novamente para acessar a agenda.',
                  confirmarLabel: 'Sair',
                  destrutivo: true,
                );
                if (sim && context.mounted) {
                  await context.read<AuthController>().sair();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.icone,
    required this.texto,
    required this.onTap,
    this.trailing,
  });

  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final Widget? trailing;
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.itens});

  final String titulo;
  final List<_Item> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10, left: 4),
          child: Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                if (i > 0) const Divider(),
                InkWell(
                  onTap: itens[i].onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: itens[i].trailing is Switch ? 10 : 18,
                    ),
                    child: Row(
                      children: [
                        Icon(itens[i].icone, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            itens[i].texto,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        itens[i].trailing ??
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
