import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/ui/widgets/design_system.dart';

void main() {
  testWidgets('scrollablePagePadding sistem bottom inset ekler', (
    tester,
  ) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          viewPadding: EdgeInsets.only(bottom: 48),
          padding: EdgeInsets.only(bottom: 48),
        ),
        child: Builder(
          builder: (context) {
            padding = scrollablePagePadding(context, bottom: 20);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(padding.left, 20);
    expect(padding.top, 20);
    expect(padding.right, 20);
    expect(padding.bottom, 68); // 20 + 48
  });

  testWidgets('scrollablePagePadding gesture inset’te de çalışır', (
    tester,
  ) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          viewPadding: EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.zero,
        ),
        child: Builder(
          builder: (context) {
            padding = scrollablePagePadding(
              context,
              horizontal: 16,
              top: 16,
              bottom: 16,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(padding.bottom, 40); // 16 + 24 viewPadding
  });
}
