import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/empresa.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/screen_header.dart';

/// Conexão de WhatsApp: mostra o estado, gera o QR code para parear o número
/// e desconecta. O MASTER informa [tenantId] (empresa de um cliente); o ADMIN
/// deixa em branco e gerencia a própria empresa.
class WhatsappScreen extends StatefulWidget {
  const WhatsappScreen({super.key, this.tenantId});

  final int? tenantId;

  @override
  State<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends State<WhatsappScreen> {
  late final WhatsappRepository _repo = context.read<WhatsappRepository>();

  WhatsappStatus? _status;
  WhatsappQr? _qr;
  String? _erro;
  bool _ocupado = false;
  Timer? _consulta;
  Timer? _renovaQr;

  static const _intervaloStatus = Duration(seconds: 3);
  // O QR code do WhatsApp expira em ~1 minuto; renovamos antes.
  static const _intervaloQr = Duration(seconds: 40);

  @override
  void initState() {
    super.initState();
    _carregarStatus();
  }

  @override
  void dispose() {
    _parar();
    super.dispose();
  }

  void _parar() {
    _consulta?.cancel();
    _renovaQr?.cancel();
    _consulta = null;
    _renovaQr = null;
  }

  Future<void> _carregarStatus() async {
    try {
      final s = await _repo.status(tenantId: widget.tenantId);
      if (!mounted) return;
      setState(() {
        _status = s;
        _erro = null;
        if (s.conectado) _qr = null;
      });
      if (s.conectado) _parar();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    }
  }

  Future<void> _gerarQr() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final qr = await _repo.conectar(tenantId: widget.tenantId);
      if (!mounted) return;
      setState(() => _qr = qr);
      if (qr.conectado) {
        await _carregarStatus();
      } else {
        _iniciarAcompanhamento();
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Enquanto o QR está na tela: confere a conexão a cada poucos segundos e
  /// renova o QR antes de expirar.
  void _iniciarAcompanhamento() {
    _parar();
    _consulta = Timer.periodic(_intervaloStatus, (_) => _carregarStatus());
    _renovaQr = Timer.periodic(_intervaloQr, (_) async {
      try {
        final qr = await _repo.conectar(tenantId: widget.tenantId);
        if (mounted && !qr.conectado) setState(() => _qr = qr);
      } catch (_) {
        // a próxima tentativa tenta de novo
      }
    });
  }

  Future<void> _desconectar() async {
    final sim = await confirmar(
      context,
      titulo: 'Desconectar o WhatsApp?',
      mensagem:
          'Os lembretes e confirmações deixam de ser enviados até conectar de novo.',
      confirmarLabel: 'Desconectar',
      destrutivo: true,
    );
    if (!sim || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final s = await _repo.desconectar(tenantId: widget.tenantId);
      if (mounted) {
        setState(() {
          _status = s;
          _qr = null;
        });
        mostrarMensagem(context, 'WhatsApp desconectado.');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, mensagemDeErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final conectado = s?.conectado ?? false;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const ScreenHeader(titulo: 'WhatsApp'),
            const SizedBox(height: 24),
            _CartaoStatus(status: s, carregando: s == null && _erro == null),
            if (_erro != null) ...[
              const SizedBox(height: 16),
              EstadoVazio(
                icone: Icons.cloud_off_outlined,
                texto: _erro!,
                onAcao: _carregarStatus,
              ),
            ],
            const SizedBox(height: 20),
            if (conectado) ...[
              const _Explicacao(
                icone: Icons.check_circle_outline,
                texto:
                    'Tudo certo! Os avisos de agendamento, lembretes de 24h e as '
                    'respostas "S" e "N" dos clientes passam por este número.',
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _ocupado ? null : _desconectar,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Desconectar'),
              ),
            ] else if (_qr != null && !_qr!.conectado) ...[
              _AreaQr(qr: _qr!),
              const SizedBox(height: 20),
              const _Passos(),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _ocupado ? null : _gerarQr,
                child: const Text('Gerar novo QR code'),
              ),
            ] else if (s != null) ...[
              const _Explicacao(
                icone: Icons.qr_code_2,
                texto:
                    'Conecte o WhatsApp da clínica para enviar confirmações e '
                    'lembretes automáticos aos clientes.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _ocupado ? null : _gerarQr,
                child: _ocupado
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Gerar QR code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoStatus extends StatelessWidget {
  const _CartaoStatus({required this.status, required this.carregando});

  final WhatsappStatus? status;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final cor = s == null
        ? AppColors.textSecondary
        : s.conectado
        ? AppColors.primary
        : s.estado == 'connecting'
        ? AppColors.warning
        : AppColors.danger;
    return AppCard(
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_rounded, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Situação',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  carregando ? 'Verificando...' : (s?.rotulo ?? 'Indisponível'),
                  style: TextStyle(
                    color: cor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaQr extends StatelessWidget {
  const _AreaQr({required this.qr});

  final WhatsappQr qr;

  @override
  Widget build(BuildContext context) {
    final bytes = qr.qr;
    return Center(
      child: Container(
        width: 288,
        height: 288,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: bytes == null
            ? const Center(child: CircularProgressIndicator())
            : Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
                semanticLabel: 'QR code do WhatsApp',
              ),
      ),
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _Passos extends StatelessWidget {
  const _Passos();

  @override
  Widget build(BuildContext context) {
    const passos = [
      'Abra o WhatsApp no celular da clínica.',
      'Toque em "Aparelhos conectados".',
      'Toque em "Conectar um aparelho" e aponte a câmera para o QR code.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < passos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    passos[i],
                    style: const TextStyle(height: 1.35, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        const Text(
          'Este QR code expira em cerca de 1 minuto; a tela renova sozinha.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
