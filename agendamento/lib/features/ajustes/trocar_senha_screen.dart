import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/auth_controller.dart';

/// Troca de senha. Com [obrigatoria] (senha provisória), não dá para voltar:
/// o app só libera o resto depois da troca.
class TrocarSenhaScreen extends StatefulWidget {
  const TrocarSenhaScreen({super.key, this.obrigatoria = false});

  final bool obrigatoria;

  @override
  State<TrocarSenhaScreen> createState() => _TrocarSenhaScreenState();
}

class _TrocarSenhaScreenState extends State<TrocarSenhaScreen> {
  final _form = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _ocultar = true;
  bool _salvando = false;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() => _salvando = true);
    try {
      await auth.alterarSenha(atual: _atual.text, nova: _nova.text);
      if (!mounted) return;
      mostrarMensagem(context, 'Senha alterada com sucesso.');
      // Na troca obrigatória o roteador já leva ao início; na voluntária, volta.
      if (!widget.obrigatoria && context.canPop()) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obrigatoria = widget.obrigatoria;
    return PopScope(
      canPop: !obrigatoria,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (obrigatoria)
                  const Text(
                    'Defina sua nova senha',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  )
                else
                  const ScreenHeader(titulo: 'Alterar senha'),
                if (obrigatoria) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Você entrou com uma senha provisória. Por segurança, escolha '
                    'uma senha só sua para continuar.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
                const SizedBox(height: 24),
                _Campo(
                  rotulo: obrigatoria ? 'Senha provisória' : 'Senha atual',
                  controller: _atual,
                  ocultar: _ocultar,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
                ),
                const SizedBox(height: 18),
                _Campo(
                  rotulo: 'Nova senha',
                  controller: _nova,
                  ocultar: _ocultar,
                  ajuda: 'Mínimo de 8 caracteres.',
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Use pelo menos 8 caracteres';
                    if (v == _atual.text) return 'A nova senha precisa ser diferente';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _Campo(
                  rotulo: 'Confirmar nova senha',
                  controller: _confirmacao,
                  ocultar: _ocultar,
                  aoEnviar: _salvar,
                  validator: (v) => v != _nova.text ? 'As senhas não conferem' : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                    icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    label: Text(_ocultar ? 'Mostrar senhas' : 'Ocultar senhas'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(obrigatoria ? 'Salvar e continuar' : 'Alterar senha'),
                ),
                if (obrigatoria) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _salvando
                          ? null
                          : () => context.read<AuthController>().sair(),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      child: const Text('Sair da conta'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.rotulo,
    required this.controller,
    required this.ocultar,
    required this.validator,
    this.ajuda,
    this.aoEnviar,
  });

  final String rotulo;
  final TextEditingController controller;
  final bool ocultar;
  final String? Function(String?) validator;
  final String? ajuda;
  final VoidCallback? aoEnviar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            rotulo,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: ocultar,
          textInputAction: aoEnviar == null ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: aoEnviar == null ? null : (_) => aoEnviar!(),
          decoration: InputDecoration(helperText: ajuda),
          validator: validator,
        ),
      ],
    );
  }
}
