import 'package:agendamento/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(VoidCallback aoTerminar, {bool reduzirAnimacoes = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduzirAnimacoes),
    child: MaterialApp(home: SplashScreen(aoTerminar: aoTerminar)),
  );
}

void main() {
  testWidgets('mostra o nome e termina sozinha uma única vez', (tester) async {
    var terminou = 0;
    await tester.pumpWidget(_app(() => terminou++));

    expect(find.text('Cronvia'), findsOneWidget);
    expect(terminou, 0);

    // Animação (2200ms) + pausa (450ms) + saída (250ms).
    await tester.pump(const Duration(milliseconds: 1000));
    expect(terminou, 0);
    await tester.pump(const Duration(milliseconds: 1500)); // anima até o fim
    await tester.pump(const Duration(milliseconds: 500)); // pausa final
    await tester.pump(const Duration(milliseconds: 300)); // fade de saída
    expect(terminou, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(terminou, 1);
  });

  testWidgets('tocar pula a animação', (tester) async {
    var terminou = 0;
    await tester.pumpWidget(_app(() => terminou++));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(SplashScreen));
    await tester.pump(const Duration(milliseconds: 300));

    expect(terminou, 1);

    // Tocar de novo ou esperar o fim da animação não chama de novo.
    await tester.pump(const Duration(seconds: 4));
    expect(terminou, 1);
  });

  testWidgets('com "reduzir animações" mostra o quadro final e segue', (
    tester,
  ) async {
    var terminou = 0;
    await tester.pumpWidget(_app(() => terminou++, reduzirAnimacoes: true));

    expect(find.text('Cronvia'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(terminou, 1);
  });
}
