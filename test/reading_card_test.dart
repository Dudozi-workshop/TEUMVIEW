import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/reading_card.dart';

void main() {
  testWidgets('resizing a weather tile keeps its reading and action', (
    tester,
  ) async {
    var taps = 0;
    for (final size in [const Size(240, 140), const Size(52, 32)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox.fromSize(
                size: size,
                child: ReadingCard(
                  label: '날씨',
                  value: '18°',
                  detail: '맑음',
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('18°'), findsOneWidget);
      expect(
        find.text('맑음'),
        size.height > 100 ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.byType(ReadingCard));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
  });
}
