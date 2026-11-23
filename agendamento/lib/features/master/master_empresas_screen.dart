import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/empresa.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../state/empresas_controller.dart';
import 'situacao_chip.dart';

enum _Filtro {
  todas('Todas'),
  ativas('Ativas'),
  suspensas('Suspensas'),
  vencidas('Vencidas');

  const _Filtro(this.rotulo);
  final String rotulo;

  bool aceita(Empresa e) => switch (this) {
    _Filtro.todas => true,
    _Filtro.ativas => e.situacao == SituacaoEmpresa.ativa,
    _Filtro.suspensas => e.situacao == SituacaoEmpresa.suspensa,
    _Filtro.vencidas => e.situacao == SituacaoEmpresa.vencida,
  };
}

/// Painel do MASTER: lista das empresas clientes.
class MasterEmpresasScreen extends StatefulWidget {
  const MasterEmpresasScreen({super.key});

  @override
  State<MasterEmpresasScreen> createState() => _MasterEmpresasScreenState();
}

class _MasterEmpresasScreenState extends State<MasterEmpresasScreen> {
  String _busca = '';
  _Filtro _filtro = _Filtro.todas;

  bool _passaNaBusca(Empresa e) {
    final termo = semAcento(_busca.trim().toLowerCase());
    if (termo.isEmpty) return true;
    final digitos = termo.replaceAll(RegExp(r'\D'), '');
    return semAcento(e.nomeFantasia.toLowerCase()).contains(termo) ||
        (digitos.isNotEmpty && e.documento.contains(digitos)) ||
        semAcento((e.adminEmail ?? '').toLowerCase()).contains(termo);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EmpresasController>();
    final todas = ctrl.empresas;
    final lista = [
      for (final e in todas)
        if (_filtro.aceita(e) && _passaNaBusca(e)) e,
    ];
    final ativas = todas.where((e) => e.situacao == SituacaoEmpresa.ativa).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova empresa',
        onPressed: () => context.push('/master/empresas/nova'),
        child: const Icon(Icons.add_business_outlined, size: 26),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Empresas',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              Text(
                todas.isEmpty
                    ? 'Clínicas cadastradas no Cronvia'
                    : '${todas.length} ${todas.length == 1 ? 'empresa' : 'empresas'} · $ativas ${ativas == 1 ? 'ativa' : 'ativas'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome, CNPJ/CPF ou e-mail',
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in _Filtro.values) ...[
                      _ChipFiltro(
                        rotulo: f.rotulo,
                        selecionado: f == _filtro,
                        onTap: () => setState(() => _filtro = f),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: lista.isEmpty
                    ? EstadoVazio(
                        icone: ctrl.erro != null
                            ? Icons.cloud_off_outlined
                            : Icons.apartment_outlined,
                        texto: ctrl.carregando
                            ? 'Carregando empresas...'
                            : ctrl.erro ?? 'Nenhuma empresa encontrada',
                        onAcao: ctrl.erro != null && !ctrl.carregando
                            ? ctrl.carregar
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: ctrl.carregar,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 6, bottom: 96),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _CardEmpresa(empresa: lista[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? AppColors.primary : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(
        side: BorderSide(
          color: selecionado ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Text(
              rotulo,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selecionado ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardEmpresa extends StatelessWidget {
  const _CardEmpresa({required this.empresa});

  final Empresa empresa;

  @override
  Widget build(BuildContext context) {
    final e = empresa;
    return AppCard(
      onTap: () => context.push('/master/empresas/${e.id}'),
      child: Row(
        children: [
          InitialsAvatar(nome: e.nomeFantasia, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.nomeFantasia,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  e.documentoFormatado,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.totalClientes} clientes · ${e.totalAgendamentos} agend.'
                  '${e.plano == null ? '' : ' · ${e.plano}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SituacaoChip(situacao: e.situacao),
        ],
      ),
    );
  }
}
