import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/slots.dart';
import '../../data/models/cliente.dart';
import '../../data/models/servico.dart';
import '../../shared/widgets/day_strip.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/picker_field.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/agenda_controller.dart';
import '../../state/clientes_controller.dart';
import '../../state/consultorio_controller.dart';

class AgendarScreen extends StatefulWidget {
  const AgendarScreen({super.key, this.clienteId, this.data});

  final int? clienteId;
  final DateTime? data;

  @override
  State<AgendarScreen> createState() => _AgendarScreenState();
}

class _AgendarScreenState extends State<AgendarScreen> {
  Cliente? _cliente;
  Servico? _servico;
  late DateTime _data;
  DateTime? _horario;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _data = soData(widget.data ?? DateTime.now());
    _cliente = context.read<ClientesController>().porId(widget.clienteId);
  }

  Future<void> _escolherCliente() async {
    final clientes = [...context.read<ClientesController>().clientes]
      ..sort((a, b) => semAcento(a.nome).compareTo(semAcento(b.nome)));
    final escolhido = await showPickerSheet<Cliente>(
      context,
      titulo: 'Selecionar cliente',
      itens: clientes,
      rotuloDe: (c) => c.nome,
      subtituloDe: (c) => c.telefoneFormatado,
      buscavel: true,
    );
    if (escolhido != null) setState(() => _cliente = escolhido);
  }

  Future<void> _escolherServico() async {
    final servicos = context.read<ConsultorioController>().servicos;
    if (servicos.isEmpty) {
      mostrarMensagem(
        context,
        'Cadastre um serviço em Consultório para definir a duração.',
        erro: true,
      );
      return;
    }
    final escolhido = await showPickerSheet<Servico>(
      context,
      titulo: 'Selecionar serviço',
      itens: servicos,
      rotuloDe: (s) => s.nome,
      subtituloDe: (s) =>
          '${duracaoLabel(s.duracaoMin)} · ${formatarMoeda(s.valor)}',
    );
    if (escolhido != null) {
      setState(() {
        _servico = escolhido;
        _horario = null;
      });
    }
  }

  Future<void> _confirmar() async {
    final cliente = _cliente;
    final servico = _servico;
    final horario = _horario;
    if (cliente == null || servico == null || horario == null) return;

    final agenda = context.read<AgendaController>();
    setState(() => _salvando = true);
    try {
      await agenda.criar(
        cliente: cliente,
        inicio: horario,
        duracaoMin: servico.duracaoMin,
      );
      agenda.selecionarData(_data);
      if (!mounted) return;
      mostrarMensagem(
        context,
        '${cliente.nome} receberá a confirmação por WhatsApp.',
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        mostrarMensagem(context, mensagemDeErro(e), erro: true);
      }
    }
  }

  void _mudarData(DateTime nova) => setState(() {
    _data = soData(nova);
    _horario = null;
  });

  @override
  Widget build(BuildContext context) {
    final consultorio = context.watch<ConsultorioController>().consultorio;
    final agenda = context.watch<AgendaController>();
    final servico = _servico;

    final livres = servico == null
        ? <DateTime>[]
        : calcularHorariosLivres(
            dia: _data,
            servico: servico,
            horarios: consultorio.horarios,
            agendamentos: agenda.agendamentos,
          );
    final pronto = _cliente != null && servico != null && _horario != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  const ScreenHeader(titulo: 'Novo agendamento'),
                  const SizedBox(height: 24),
                  PickerField(
                    rotulo: 'Cliente',
                    placeholder: 'Selecionar cliente',
                    valor: _cliente?.nome,
                    onTap: _escolherCliente,
                  ),
                  const SizedBox(height: 20),
                  PickerField(
                    rotulo: 'Serviço',
                    placeholder: 'Selecionar serviço',
                    valor: servico?.nome,
                    onTap: _escolherServico,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Data · ${formatarMesAno(_data)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      RoundIconButton(
                        icon: Icons.chevron_left,
                        size: 36,
                        tooltip: 'Semana anterior',
                        onPressed: () => _mudarData(somarDias(_data, -7)),
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: Icons.chevron_right,
                        size: 36,
                        tooltip: 'Próxima semana',
                        onPressed: () => _mudarData(somarDias(_data, 7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DayStrip(selecionado: _data, onSelect: _mudarData),
                  const SizedBox(height: 24),
                  const Text(
                    'Horário',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (servico == null)
                    const _Aviso('Selecione um serviço para ver os horários.')
                  else if (livres.isEmpty)
                    const _Aviso('Sem horários livres neste dia.')
                  else
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.9,
                      children: [
                        for (final h in livres)
                          _Horario(
                            hora: formatarHora(h),
                            selecionado: h == _horario,
                            onTap: () => setState(() => _horario = h),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: pronto && !_salvando ? _confirmar : null,
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Confirmar agendamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Horario extends StatelessWidget {
  const _Horario({
    required this.hora,
    required this.selecionado,
    required this.onTap,
  });

  final String hora;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? AppColors.primary : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selecionado ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            hora,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selecionado ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
