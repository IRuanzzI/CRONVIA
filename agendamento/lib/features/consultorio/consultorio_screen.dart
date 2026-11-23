import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/servico.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/info_rows.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_title.dart';
import '../../state/agenda_controller.dart';
import '../../state/consultorio_controller.dart';

class ConsultorioScreen extends StatelessWidget {
  const ConsultorioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ConsultorioController>();
    final c = ctrl.consultorio;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(titulo: 'Consultório'),
            const SizedBox(height: 24),
            AppCard(
              radius: 24,
              onTap: () => _abrirDados(context),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: AppColors.onPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nome,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          c.endereco.isEmpty
                              ? 'Toque para adicionar o endereço'
                              : c.endereco,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Horário de funcionamento'),
            const SizedBox(height: 12),
            InfoRows(
              rows: [
                for (var i = 0; i < c.horarios.length; i++)
                  InfoRow(
                    c.horarios[i].rotulo,
                    c.horarios[i].faixa,
                    onTap: () => _editarHorario(context, i),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: SectionTitle('Serviços')),
                OutlinedButton(
                  onPressed: () => _abrirServico(context, null),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('+ Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (ctrl.servicos.isEmpty)
              const EstadoVazio(
                icone: Icons.medical_services_outlined,
                texto: 'Nenhum serviço cadastrado',
              )
            else
              for (final s in ctrl.servicos) ...[
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  onTap: () => _abrirServico(context, s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.nome,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              duracaoLabel(s.duracaoMin),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatarMoeda(s.valor),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _editarHorario(BuildContext context, int indice) async {
    final ctrl = context.read<ConsultorioController>();
    final h = ctrl.consultorio.horarios[indice];

    Future<int?> escolher(String ajuda, int atual) async {
      final t = await showTimePicker(
        context: context,
        helpText: ajuda,
        initialTime: TimeOfDay(hour: atual ~/ 60, minute: atual % 60),
      );
      return t == null ? null : t.hour * 60 + t.minute;
    }

    final abre = await escolher('Abre às · ${h.rotulo}', h.abreMin);
    if (abre == null || !context.mounted) return;
    final fecha = await escolher('Fecha às · ${h.rotulo}', h.fechaMin);
    if (fecha == null || !context.mounted) return;
    if (fecha <= abre) {
      mostrarMensagem(
        context,
        'O fechamento precisa ser depois da abertura.',
        erro: true,
      );
      return;
    }
    try {
      await ctrl.atualizarHorario(indice, abre, fecha);
    } catch (e) {
      if (context.mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  void _abrirDados(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DadosSheet(),
    );
  }

  void _abrirServico(BuildContext context, Servico? servico) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ServicoSheet(servico: servico),
    );
  }
}

class _SheetBase extends StatelessWidget {
  const _SheetBase({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
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

class _BotaoCarregando extends StatelessWidget {
  const _BotaoCarregando({required this.carregando, required this.texto});

  final bool carregando;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return carregando
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.onPrimary,
            ),
          )
        : Text(texto);
  }
}

class _DadosSheet extends StatefulWidget {
  const _DadosSheet();

  @override
  State<_DadosSheet> createState() => _DadosSheetState();
}

class _DadosSheetState extends State<_DadosSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _endereco;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<ConsultorioController>().consultorio;
    _endereco = TextEditingController(text: c.endereco);
  }

  @override
  void dispose() {
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final ctrl = context.read<ConsultorioController>();
    final navigator = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      await ctrl.atualizarEndereco(_endereco.text.trim());
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      titulo: 'Endereço do consultório',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Rotulo('Endereço'),
              TextFormField(
                controller: _endereco,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Rua, número, bairro'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _BotaoCarregando(carregando: _salvando, texto: 'Salvar'),
        ),
      ],
    );
  }
}

class _ServicoSheet extends StatefulWidget {
  const _ServicoSheet({this.servico});

  final Servico? servico;

  @override
  State<_ServicoSheet> createState() => _ServicoSheetState();
}

class _ServicoSheetState extends State<_ServicoSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _duracao;
  late final TextEditingController _valor;
  bool _salvando = false;

  bool get _editando => widget.servico != null;

  @override
  void initState() {
    super.initState();
    final s = widget.servico;
    _nome = TextEditingController(text: s?.nome ?? '');
    _duracao = TextEditingController(text: s == null ? '' : '${s.duracaoMin}');
    _valor = TextEditingController(
      text: s == null ? '' : s.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _duracao.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final ctrl = context.read<ConsultorioController>();
    final agenda = context.read<AgendaController>();
    final navigator = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      await ctrl.salvarServico(
        Servico(
          id: widget.servico?.id ?? 0,
          nome: _nome.text.trim(),
          duracaoMin: int.parse(_duracao.text),
          valor: lerMoeda(_valor.text) ?? 0,
        ),
      );
      if (_editando) await agenda.carregar();
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  Future<void> _excluir() async {
    final servico = widget.servico;
    if (servico == null) return;
    final ctrl = context.read<ConsultorioController>();
    final navigator = Navigator.of(context);
    final sim = await confirmar(
      context,
      titulo: 'Excluir serviço?',
      mensagem: '"${servico.nome}" será removido da lista de serviços.',
      confirmarLabel: 'Excluir',
      destrutivo: true,
    );
    if (!sim || !mounted) return;
    try {
      await ctrl.excluirServico(servico.id);
      navigator.pop();
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      titulo: _editando ? 'Editar serviço' : 'Novo serviço',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Rotulo('Nome do serviço'),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Ex.: Consulta'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Rotulo('Duração (min)'),
                        TextFormField(
                          controller: _duracao,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(hintText: '45'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n <= 0) ? 'Inválida' : null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Rotulo('Valor (R\$)'),
                        TextFormField(
                          controller: _valor,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(hintText: '150,00'),
                          validator: (v) {
                            final n = lerMoeda(v ?? '');
                            return (n == null || n < 0) ? 'Inválido' : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _BotaoCarregando(carregando: _salvando, texto: 'Salvar'),
        ),
        if (_editando) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _excluir,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Excluir serviço'),
          ),
        ],
      ],
    );
  }
}
