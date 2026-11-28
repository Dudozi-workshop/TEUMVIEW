import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teumview/board_store.dart';
import 'package:teumview/main.dart';

void main() {
  testWidgets('landscape template selection survives leaving edit mode with Back', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'intro_seen': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(home: Dashboard(
      prefs: prefs, surface: Colors.grey, onSettings: () {},
      burnin: false, lowPower: true, radius: 8, photo: null,
    )));
    await tester.longPressAt(const Offset(550, 250));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('추천 템플릿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 중심'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('실행 취소'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('완료'), findsNothing);
    expect(find.byType(Dashboard), findsOneWidget);
    expect(BoardStore(prefs).load('default', true).tiles.map((t) => t.kind),
        ['photo', 'clock', 'date', 'dday']);
    expect(BoardStore(prefs).load('default', false).tiles.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
