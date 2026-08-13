import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/ui/widgets/simple_markdown.dart';

void main() {
  testWidgets('SimpleMarkdownView başlık, kalın ve liste render eder', (
    tester,
  ) async {
    const md = '''
# Başlık Bir

## Alt başlık

Paragraf içinde **kalın** metin.

- İlk madde
- İkinci madde
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: SimpleMarkdownView(data: md)),
        ),
      ),
    );

    expect(find.text('Başlık Bir'), findsOneWidget);
    expect(find.text('Alt başlık'), findsOneWidget);
    expect(find.textContaining('kalın'), findsOneWidget);
    expect(find.textContaining('İlk madde'), findsOneWidget);
    expect(find.text('#'), findsNothing);
    expect(find.text('##'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('Markdown soft break satırları birleştirmez', (tester) async {
    // İki sonda boşluk = Markdown soft line break
    const md =
        '**Son güncelleme:** 7 Ağustos 2026  \n'
        '**Uygulama:** KiraRota  \n'
        '**Geliştirici:** Tyreest Studio\n';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: SimpleMarkdownView(data: md)),
        ),
      ),
    );

    expect(find.textContaining('Son güncelleme:'), findsOneWidget);
    expect(find.textContaining('Uygulama:'), findsOneWidget);
    expect(find.textContaining('Geliştirici:'), findsOneWidget);
    // Tek paragrafta birleşmiş olmamalı
    expect(
      find.textContaining('Son güncelleme: 7 Ağustos 2026 Uygulama:'),
      findsNothing,
    );
  });
}
