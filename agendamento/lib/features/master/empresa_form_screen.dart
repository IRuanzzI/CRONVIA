import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/empresa.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/picker_field.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/empresas_controller.dart';
import 'vencimento_picker.dart';

const planosDisponiveis = ['TESTE', 'BASICO', 'PROFISSIONAL'];

/// Cadastro de uma empresa nova + o administrador dela.
class EmpresaFormScreen extends StatefulWidget {
  const EmpresaFormScreen({super.key});

  @override
  State<EmpresaFormScreen> createState() => _EmpresaFormScreenState();
}

class _EmpresaFormScreenState extends State<EmpresaFormScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _documento = TextEditingController();
  final _adminNome = TextEditingController();
  final _adminEmail = TextEditingController();
  late final TextEditingController _senha = TextEditingController(
    text: gerarSenhaProvisoria(),
  );
  String _plano = 'TESTE';
  DateTime? _venceEm;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _documento.dispose();
    _adminNome.dispose();
    _adminEmail.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _escolherPlano() async {
    final p = await showPickerSheet<String>(
      context,
      titulo: 'Plano',
      itens: planosDisponiveis,
      rotuloDe: (p) => p,
    );
    if (p != null) setState(() => _plano = p);
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final ctrl = context.read<EmpresasController>();
    final senha = _senha.text;
    final email = _adminEmail.text.trim();
    setState(() => _salvando = true);
    try {
      final empresa = await ctrl.criar(
        NovaEmpresa(
          nomeFantasia: _nome.text.trim(),
          documento: _documento.text.replaceAll(RegExp(r'\D'), ''),
          adminNome: _adminNome.text.trim(),
          adminEmail: email,
          adminSenha: senha,
          plano: _plano,
          venceEm: _venceEm,
        ),
      );
      if (!mounted) return;
      await mostrarAcessoCriado(
        context,
        titulo: 'Empresa cadastrada',
        empresa: empresa.nomeFantasia,
        email: email,
        senha: senha,
      );
      if (mounted) context.pushReplacement('/master/empresas/${empresa.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const ScreenHeader(titulo: 'Nova empresa'),
              const SizedBox(height: 24),
              const _Secao('Empresa'),
              const _Rotulo('Nome fantasia'),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Ex.: Clínica Vida Plena'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              const _Rotulo('CNPJ ou CPF'),
              TextFormField(
                controller: _documento,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [DocumentoInputFormatter()],
                decoration: const InputDecoration(hintText: '00.000.000/0000-00'),
                validator: (v) {
                  final n = (v ?? '').replaceAll(RegExp(r'\D'), '').length;
                  return (n == 11 || n == 14)
                      ? null
                      : 'Informe um CPF (11) ou CNPJ (14 dígitos)';
                },
              ),
              const SizedBox(height: 16),
              PickerField(
                rotulo: 'Plano',
                placeholder: 'Selecionar plano',
                valor: _plano,
                onTap: _escolherPlano,
              ),
              const SizedBox(height: 16),
              VencimentoPicker(
                valor: _venceEm,
                onChanged: (d) => setState(() => _venceEm = d),
              ),
              const SizedBox(height: 28),
              const _Secao('Administrador da empresa'),
              const _Rotulo('Nome'),
              TextFormField(
                controller: _adminNome,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nome do responsável'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              const _Rotulo('E-mail (será o login)'),
              TextFormField(
                controller: _adminEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'admin@clinica.com'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Informe o e-mail';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'E-mail inválido';
                },
              ),
              const SizedBox(height: 16),
              const _Rotulo('Senha provisória'),
              TextFormField(
                controller: _senha,
                decoration: InputDecoration(
                  helperText:
                      'O admin será obrigado a trocar esta senha no primeiro acesso.',
                  helperMaxLines: 2,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Gerar outra',
                        icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                        onPressed: () => setState(
                          () => _senha.text = gerarSenhaProvisoria(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar',
                        icon: const Icon(Icons.copy_outlined, color: AppColors.textSecondary),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _senha.text));
                          if (context.mounted) mostrarMensagem(context, 'Senha copiada.');
                        },
                      ),
                    ],
                  ),
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Use pelo menos 8 caracteres'
                    : null,
              ),
              const SizedBox(height: 28),
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
                    : const Text('Cadastrar empresa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostra os dados de acesso (e-mail + senha provisória) com botão de copiar.
/// A senha só aparece aqui: depois ela não pode ser consultada.
Future<void> mostrarAcessoCriado(
  BuildContext context, {
  required String titulo,
  required String empresa,
  required String email,
  required String senha,
}) {
  final texto =
      'Cronvia — acesso de $empresa\nE-mail: $email\nSenha provisória: $senha\n'
      '(troque a senha no primeiro acesso)';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Envie estes dados ao administrador. A senha provisória só aparece agora.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              'E-mail\n$email\n\nSenha provisória\n$senha',
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (ctx.mounted) mostrarMensagem(ctx, 'Dados copiados.');
          },
          child: const Text('Copiar dados'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Concluir'),
        ),
      ],
    ),
  );
}

class _Secao extends StatelessWidget {
  const _Secao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
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
