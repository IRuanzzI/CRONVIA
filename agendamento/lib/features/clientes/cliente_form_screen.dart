import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cliente.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/agenda_controller.dart';
import '../../state/clientes_controller.dart';

/// Cria um cliente (`clienteId == null`) ou edita um existente.
class ClienteFormScreen extends StatefulWidget {
  const ClienteFormScreen({super.key, this.clienteId});

  final int? clienteId;

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  Cliente? _existente;
  bool _salvando = false;

  bool get _editando => widget.clienteId != null;

  @override
  void initState() {
    super.initState();
    _existente = context.read<ClientesController>().porId(widget.clienteId);
    _nome = TextEditingController(text: _existente?.nome ?? '');
    _telefone = TextEditingController(
      text: _existente?.telefoneFormatado ?? '',
    );
    _email = TextEditingController(text: _existente?.email ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final clientes = context.read<ClientesController>();
    final agenda = context.read<AgendaController>();
    setState(() => _salvando = true);
    try {
      final existente = _existente;
      if (existente != null) {
        await clientes.atualizar(
          existente.copyWith(
            nome: _nome.text.trim(),
            telefone: _telefone.text.trim(),
            email: _email.text.trim(),
          ),
        );
        await agenda.carregar();
      } else {
        await clientes.criar(
          nome: _nome.text.trim(),
          telefone: _telefone.text.trim(),
          email: _email.text.trim(),
        );
      }
      if (!mounted) return;
      mostrarMensagem(
        context,
        _editando ? 'Cliente atualizado.' : 'Cliente cadastrado.',
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  Future<void> _excluir() async {
    final existente = _existente;
    if (existente == null) return;
    final clientes = context.read<ClientesController>();
    final sim = await confirmar(
      context,
      titulo: 'Excluir cliente?',
      mensagem: '${existente.nome} será removido. Esta ação não pode ser desfeita.',
      confirmarLabel: 'Excluir',
      destrutivo: true,
    );
    if (!sim || !mounted) return;
    try {
      await clientes.excluir(existente.id);
      if (!mounted) return;
      mostrarMensagem(context, 'Cliente excluído.');
      context.go('/clientes');
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
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
              ScreenHeader(titulo: _editando ? 'Editar cliente' : 'Novo cliente'),
              const SizedBox(height: 24),
              const _Rotulo('Nome'),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nome do cliente'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 20),
              const _Rotulo('Telefone (WhatsApp)'),
              TextFormField(
                controller: _telefone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9()\-\s]')),
                  TelefoneInputFormatter(),
                ],
                decoration: const InputDecoration(
                  hintText: '(11) 91234-5678',
                  helperText:
                      'É por este número que o cliente recebe confirmações e lembretes.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final digitos = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digitos.length < 10) return 'Informe um telefone válido';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const _Rotulo('E-mail (opcional)'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'cliente@email.com'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'E-mail inválido';
                },
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
                    : const Text('Salvar'),
              ),
              if (_editando) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _excluir,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Excluir cliente'),
                ),
              ],
            ],
          ),
        ),
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
