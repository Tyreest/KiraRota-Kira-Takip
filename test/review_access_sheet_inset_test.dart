import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/ui/widgets/review_access_sheet.dart';

Widget _sheetUnderTest({
  required Size size,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        viewPadding: viewPadding,
        padding: padding,
        viewInsets: viewInsets,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: ReviewAccessSheetScaffold(child: child),
          ),
        ),
      ),
    ),
  );
}

Widget _codeEntryActions() {
  return const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('İnceleme erişimi'),
      SizedBox(height: 12),
      TextField(decoration: InputDecoration(labelText: 'Kod')),
      SizedBox(height: 16),
      FilledButton(onPressed: null, child: Text('Doğrula')),
      TextButton(onPressed: null, child: Text('İptal')),
    ],
  );
}

void main() {
  testWidgets(
    'bottom system inset varken İptal görünür ve tıklanabilir alanda',
    (tester) async {
      const size = Size(400, 800);
      const navInset = 48.0;
      await tester.pumpWidget(
        _sheetUnderTest(
          size: size,
          viewPadding: const EdgeInsets.only(bottom: navInset),
          padding: const EdgeInsets.only(bottom: navInset),
          child: _codeEntryActions(),
        ),
      );
      await tester.pumpAndSettle();

      final cancel = find.text('İptal');
      expect(cancel, findsOneWidget);

      final rect = tester.getRect(cancel);
      // Sistem nav alanının üstünde kalmalı
      expect(rect.bottom, lessThanOrEqualTo(size.height - navInset + 0.5));
      expect(rect.top, greaterThanOrEqualTo(0));

      // Hit-test: buton render box ekranda
      final box = tester.renderObject<RenderBox>(cancel);
      expect(box.hasSize, isTrue);
      expect(box.size.height, greaterThan(0));
    },
  );

  testWidgets('küçük ekran yüksekliğinde overflow yok', (tester) async {
    FlutterErrorDetails? overflow;
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflow = details;
      }
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      _sheetUnderTest(
        size: const Size(320, 280),
        viewPadding: const EdgeInsets.only(bottom: 48),
        padding: const EdgeInsets.only(bottom: 48),
        child: _codeEntryActions(),
      ),
    );
    await tester.pumpAndSettle();

    expect(overflow, isNull);
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Doğrula'), findsOneWidget);
  });

  testWidgets('keyboard/viewInsets iken aksiyonlar erişilebilir', (
    tester,
  ) async {
    const size = Size(400, 800);
    const keyboard = 320.0;
    const navInset = 48.0;
    // Klavye açıkken padding.bottom genelde 0; viewPadding korunur.
    await tester.pumpWidget(
      _sheetUnderTest(
        size: size,
        viewPadding: const EdgeInsets.only(bottom: navInset),
        padding: EdgeInsets.zero,
        viewInsets: const EdgeInsets.only(bottom: keyboard),
        child: _codeEntryActions(),
      ),
    );
    await tester.pumpAndSettle();

    final cancel = find.text('İptal');
    expect(cancel, findsOneWidget);
    final rect = tester.getRect(cancel);
    // Klavye üstünde görünür alan: height - keyboard
    final visibleBottom = size.height - keyboard;
    expect(rect.bottom, lessThanOrEqualTo(visibleBottom + 0.5));
    expect(rect.top, lessThan(visibleBottom));
  });
}
