import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/empresa.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/info_rows.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/picker_field.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_title.dart';
import '../../state/empresas_controller.dart';
import 'empresa_form_screen.dart';
import 'situacao_chip.dart';
import 'vencimento_picker.dart';

class EmpresaDetalheScreen extends StatefulWidget {
  const EmpresaDetalheScreen({super.key, required this.id});

  final int id;

  @override
  State<EmpresaDetalheScreen> createState() => _EmpresaDetalheScreenState();
}

class _EmpresaDetalheScreenState extends State<EmpresaDetalheScreen> {
  List<AuditoriaItem>? _auditoria;
  String? _erroAuditoria;
  bool _agindo = false;

  @override
  void initState() {
    super.initState();
    _carregarAuditoria();
  }

  Future<void> _carregarAuditoria() async {
    try {
      final itens = await context.read<EmpresasController>().auditoria(widget.id);
      if (mounted) {
        setState(() {
          _auditoria = itens;
          _erroAuditoria = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erroAuditoria = mensagemDeErro(e));
    }
  }

  /// Executa uma ação do painel, avisando o resultado e atualizando o histórico.
  Future<void> _agir(Future<void> Function() acao, {String? sucesso}) async {
    setState(() => _agindo = true);
    try {
      await acao();
      if (mounted && sucesso != null) mostrarMensagem(context, sucesso);
      await _carregarAuditoria();
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _agindo = false);
    }
  }

  Future<void> _alternarSuspensao(Empresa e) async {
    final suspender = e.ativo;
    final sim = await confirmar(
      context,
      titulo: suspender ? 'Suspender empresa?' : 'Reativar empresa?',
      mensagem: suspender
          ? 'Os usuários de ${e.nomeFantasia} perdem o acesso na hora, '
                'inclusive quem já está logado. Você pode reativar quando quiser.'
          : '${e.nomeFantasia} volta a acessar o Cronvia.',
      confirmarLabel: suspender ? 'Suspender' : 'Reativar',
      destrutivo: suspender,
    );
    if (!sim || !mounted) return;
    final ctrl = context.read<EmpresasController>();
    await _agir(
      () => ctrl.definirAtivo(e.id, ativo: !suspender),
      sucesso: suspender ? 'Empresa suspensa.' : 'Empresa reativada.',
    );
  }

  Future<void> _redefinirSenha(Empresa e) async {
    final sim = await confirmar(
      context,
      titulo: 'Redefinir senha do admin?',
      mensagem:
          'Será gerada uma senha provisória para ${e.adminEmail ?? 'o admin'}. '
          'A senha atual deixa de funcionar e ele precisará trocar no próximo acesso.',
      confirmarLabel: 'Redefinir',
      destrutivo: true,
    );
    if (!sim || !mounted) return;
    final ctrl = context.read<EmpresasController>();
    SenhaTemporaria? nova;
    await _agir(() async => nova = await ctrl.redefinirSenhaAdmin(e.id));
    final dados = nova;
    if (dados != null && mounted) {
      await mostrarAcessoCriado(
        context,
        titulo: 'Senha redefinida',
        empresa: e.nomeFantasia,
        email: dados.email,
        senha: dados.senha,
      );
    }
  }

  Future<void> _editar(Empresa e) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditarSheet(empresa: e, aoSalvar: _carregarAuditoria),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EmpresasController>().porId(widget.id);
    if (e == null) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ScreenHeader(titulo: 'Empresa'),
          ),
        ),
      );
    }
    final ehProprio = e.id == 1; // empresa do próprio MASTER não é suspensa por aqui

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            ScreenHeader(titulo: e.nomeFantasia),
            const SizedBox(height: 20),
            Row(
              children: [
                InitialsAvatar(nome: e.nomeFantasia, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          SituacaoChip(situacao: e.situacao),
                          if (e.plano != null) _PlanoChip(e.plano!),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.documentoFormatado,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (e.situacao != SituacaoEmpresa.ativa) ...[
              const SizedBox(height: 16),
              _Aviso(
                cor: corDaSituacao(e.situacao),
                texto: e.situacao == SituacaoEmpresa.suspensa
                    ? 'Empresa suspensa: ninguém desta empresa consegue entrar.'
                    : 'Assinatura vencida: ninguém desta empresa consegue entrar até renovar.',
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _Numero(valor: e.totalClientes, rotulo: 'Clientes')),
                const SizedBox(width: 12),
                Expanded(child: _Numero(valor: e.totalAgendamentos, rotulo: 'Agendamentos')),
              ],
            ),
            const SizedBox(height: 16),
            InfoRows(
              rows: [
                InfoRow('Vencimento', _textoVencimento(e)),
                InfoRow('Administrador', e.adminNome ?? '—'),
                InfoRow('E-mail do admin', e.adminEmail ?? '—'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _agindo ? null : () => _editar(e),
                    child: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _agindo || ehProprio ? null : () => _alternarSuspensao(e),
                    style: e.ativo
                        ? FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: AppColors.onPrimary,
                          )
                        : null,
                    child: Text(e.ativo ? 'Suspender' : 'Reativar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _agindo || e.adminEmail == null ? null : () => _redefinirSenha(e),
              icon: const Icon(Icons.lock_reset_outlined),
              label: const Text('Redefinir senha do admin'),
            ),
            const SizedBox(height: 20),
            AppCard(
              onTap: () => context.push('/master/empresas/${e.id}/whatsapp'),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Conectar o número da clínica (QR code)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Histórico'),
            const SizedBox(height: 12),
            if (_erroAuditoria != null)
              EstadoVazio(
                icone: Icons.cloud_off_outlined,
                texto: _erroAuditoria!,
                onAcao: _carregarAuditoria,
              )
            else if (_auditoria == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_auditoria!.isEmpty)
              const EstadoVazio(
                icone: Icons.history,
                texto: 'Nenhuma ação registrada ainda',
              )
            else
              for (final a in _auditoria!) ...[
                _LinhaAuditoria(item: a),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  String _textoVencimento(Empresa e) {
    final v = e.venceEm;
    if (v == null) return 'Sem vencimento';
    final dias = e.diasParaVencer!;
    final quando = dias == 0
        ? 'vence hoje'
        : dias > 0
        ? 'em $dias ${dias == 1 ? 'dia' : 'dias'}'
        : 'há ${-dias} ${dias == -1 ? 'dia' : 'dias'}';
    return '${formatarData(v)} · $quando';
  }
}

class _PlanoChip extends StatelessWidget {
  const _PlanoChip(this.plano);

  final String plano;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plano,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$valor',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          Text(rotulo, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _LinhaAuditoria extends StatelessWidget {
  const _LinhaAuditoria({required this.item});

  final AuditoriaItem item;

  @override
  Widget build(BuildContext context) {
    final quando = '${formatarDiaMes(item.quando)} às ${formatarHora(item.quando)}';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.acaoLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                quando,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'por ${item.ator}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (item.detalhe != null && item.detalhe!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.detalhe!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditarSheet extends StatefulWidget {
  const _EditarSheet({required this.empresa, required this.aoSalvar});

  final Empresa empresa;
  final Future<void> Function() aoSalvar;

  @override
  State<_EditarSheet> createState() => _EditarSheetState();
}

class _EditarSheetState extends State<_EditarSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome = TextEditingController(
    text: widget.empresa.nomeFantasia,
  );
  late String _plano = widget.empresa.plano ?? 'TESTE';
  late DateTime? _venceEm = widget.empresa.venceEm;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final ctrl = context.read<EmpresasController>();
    final navigator = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      await ctrl.atualizar(
        widget.empresa.id,
        nomeFantasia: _nome.text.trim(),
        plano: _plano,
        venceEm: _venceEm,
      );
      await widget.aoSalvar();
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
    final planos = {...planosDisponiveis, _plano}.toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar empresa',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nome fantasia',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              PickerField(
                rotulo: 'Plano',
                placeholder: 'Selecionar plano',
                valor: _plano,
                onTap: () async {
                  final p = await showPickerSheet<String>(
                    context,
                    titulo: 'Plano',
                    itens: planos,
                    rotuloDe: (p) => p,
                  );
                  if (p != null) setState(() => _plano = p);
                },
              ),
              const SizedBox(height: 16),
              VencimentoPicker(
                valor: _venceEm,
                onChanged: (d) => setState(() => _venceEm = d),
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
