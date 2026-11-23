import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feedback.dart';
import '../../state/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

Future<void> enviarEmail() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'solucoescorporativorga@gmail.com',
    queryParameters: {
      'subject': 'Contato pelo aplicativo Cronvia',
      'body': 'Olá! Estou entrando em contato pelo aplicativo Cronvia.',
    },
  );

  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregando = false;
  @override
  void initState() {
    super.initState();
    // Sessão encerrada pelo servidor (empresa suspensa/vencida): avisa o motivo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final aviso = context.read<AuthController>().consumirAviso();
      if (aviso != null) mostrarMensagem(context, aviso, erro: true);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() => _carregando = true);
    try {
      await auth.login(_email.text.trim(), _senha.text);
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Marca(),
                    const SizedBox(height: 48),
                    const Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _Rotulo('E-mail'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        hintText: 'voce@empresa.com',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Informe seu e-mail';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(t)) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const _Rotulo('Senha'),
                    TextFormField(
                      controller: _senha,
                      obscureText: _ocultarSenha,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        hintText: 'Sua senha',
                        suffixIcon: IconButton(
                          tooltip: _ocultarSenha
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () =>
                              setState(() => _ocultarSenha = !_ocultarSenha),
                          icon: Icon(
                            _ocultarSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => mostrarMensagem(
                          context,
                          'Peça ao administrador da sua empresa para redefinir a senha.',
                        ),
                        child: const Text(
                          'Esqueci minha senha',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    Center(
                      child: Text(
                        'Versão $appVersion\n© 2026 Ruan Pablo e RGA Soluções Corporativas. Todos os direitos reservados.',

                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Image.asset(
                        logoRgaAsset,
                        width: 64,
                        height: 64,
                        semanticLabel: appName,
                      ),
                    ),
                    const SizedBox(height: 5),

                    InkWell(
                      onTap: () => enviarEmail(),
                      child: const Text(
                        'Gostou do app? Envie um e-mail para nós!',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(logoAsset, width: 64, height: 64, semanticLabel: appName),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                appTagline,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
