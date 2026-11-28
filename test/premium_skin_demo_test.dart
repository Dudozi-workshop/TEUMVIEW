import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/main.dart';
import 'package:teumview/skin.dart';

void main() {
  for (final skin in SkinStyle.premiumCatalog) {
    testWidgets('${skin.label} adapts when the phone rotates', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(MaterialApp(home: PremiumSkinDemo(style: skin)));
      expect(find.text(skin.label), findsOneWidget);
      final clock = find.text('09:41');
      final weather = find.text('18°');
      expect(tester.getCenter(clock).dy, lessThan(tester.getCenter(weather).dy));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(640, 320);
      await tester.pumpAndSettle();
      expect(tester.getCenter(clock).dx, lessThan(tester.getCenter(weather).dx));
      expect(find.text('09:00  미팅'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
