import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';

/// Abertura animada do app: a logo entra, o nome surge e uma linha (a "via")
/// se desenha com um ponto percorrendo o caminho. Toque para pular.
///
/// Depois da animação, vai para `/inicio` (o roteador leva ao login se o
/// usuário não estiver logado). Com "reduzir animações" ativado no aparelho,
/// mostra o quadro final e segue rápido.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.aoTerminar,
    this.duracao = const Duration(milliseconds: 2200),
    this.pausaFinal = const Duration(milliseconds: 450),
  });

  /// Padrão: `context.go('/inicio')`.
  final VoidCallback? aoTerminar;
  final Duration duracao;
  final Duration pausaFinal;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duracao,
  );
  bool _saindo = false;
  bool _terminou = false;
  bool _iniciou = false;

  static const _duracaoSaida = Duration(milliseconds: 250);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciou) return;
    _iniciou = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _encerrar(pausa: const Duration(milliseconds: 600));
    } else {
      _controller.forward().whenComplete(() {
        if (mounted) _encerrar(pausa: widget.pausaFinal);
      });
    }
  }

  Future<void> _encerrar({Duration pausa = Duration.zero}) async {
    await Future<void>.delayed(pausa);
    if (!mounted || _terminou) return;
    setState(() => _saindo = true);
    await Future<void>.delayed(_duracaoSaida);
    _concluir();
  }

  void _concluir() {
    if (!mounted || _terminou) return;
    _terminou = true;
    (widget.aoTerminar ?? () => context.go('/inicio'))();
  }

  /// Toque: pula a animação.
  void _pular() {
    if (_terminou || _saindo) return;
    _controller.stop();
    _controller.value = 1;
    setState(() => _saindo = true);
    Future<void>.delayed(_duracaoSaida, _concluir);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progresso (0..1) de uma etapa que vai de [a] a [b] da linha do tempo.
  static double _etapa(
    double t,
    double a,
    double b, [
    Curve curva = Curves.easeOutCubic,
  ]) => curva.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pular,
        child: AnimatedOpacity(
          opacity: _saindo ? 0 : 1,
          duration: _duracaoSaida,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final logo = _etapa(t, 0.0, 0.40, Curves.easeOutBack);
              final logoOpacidade = _etapa(t, 0.0, 0.22);
              final nome = _etapa(t, 0.30, 0.62);
              final via = _etapa(t, 0.50, 0.82, Curves.easeInOutCubic);
              final tagline = _etapa(t, 0.72, 0.96);
              // O brilho "respira" depois que a logo aparece.
              final brilho =
                  logoOpacidade * (0.75 + 0.25 * math.sin(t * 2 * math.pi * 2));

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.marca.withValues(
                                    alpha: 0.30 * brilho,
                                  ),
                                  blurRadius: 70,
                                  spreadRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          Opacity(
                            opacity: logoOpacidade,
                            child: Transform.scale(
                              scale: 0.5 + 0.5 * logo,
                              child: Image.asset(
                                logoAsset,
                                width: 150,
                                height: 150,
                                semanticLabel: appName,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: nome,
                      child: Transform.translate(
                        offset: Offset(0, (1 - nome) * 14),
                        child: Text(
                          appName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8 - 6.5 * nome,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 190,
                      height: 14,
                      child: CustomPaint(painter: _ViaPainter(via)),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: tagline,
                      child: Transform.translate(
                        offset: Offset(0, (1 - tagline) * 8),
                        child: const Text(
                          appTagline,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A "via": linha que se desenha da esquerda para a direita, com um ponto
/// luminoso na ponta (o caminho/fluxo do agendamento).
class _ViaPainter extends CustomPainter {
  _ViaPainter(this.progresso);

  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    if (progresso <= 0) return;
    final y = size.height / 2;
    final fim = size.width * progresso;

    final linha = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [AppColors.marca.withValues(alpha: 0), AppColors.marca],
      ).createShader(Rect.fromLTWH(0, 0, math.max(fim, 1), size.height));
    canvas.drawLine(Offset(0, y), Offset(fim, y), linha);

    // Ponto na ponta, com brilho.
    canvas.drawCircle(
      Offset(fim, y),
      9,
      Paint()
        ..color = AppColors.marca.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset(fim, y), 4.5, Paint()..color = AppColors.marca);
  }

  @override
  bool shouldRepaint(_ViaPainter antigo) => antigo.progresso != progresso;
}
