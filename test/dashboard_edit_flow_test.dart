import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teumview/board_store.dart';
import 'package:teumview/main.dart';

void main() {
  Future<SharedPreferences> openBoard(WidgetTester tester, Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(home: Dashboard(
      prefs: prefs, surface: Colors.grey, onSettings: () {},
      burnin: false, lowPower: true, radius: 8, photo: null,
    )));
    await tester.pumpAndSettle();
    return prefs;
  }

  testWidgets('first-run preset opens the editor, supports undo and is offered once', (tester) async {
    final prefs = await openBoard(tester, {});
    await tester.tap(find.text('사진 중심'));
    await tester.pumpAndSettle();
    final store = BoardStore(prefs);
    expect(store.load('default', true).tiles.first.kind, 'photo');
    expect(find.text('완료'), findsOneWidget);
    await tester.tap(find.byTooltip('실행 취소'));
    await tester.pumpAndSettle();
    expect(store.load('default', true).tiles.length, 2);
    expect(prefs.getBool('intro_seen'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skip keeps the clock and a long press selects it for editing', (tester) async {
    final prefs = await openBoard(tester, {});
    await tester.tap(find.text('기본 시계로 시작'));
    await tester.pumpAndSettle();
    expect(find.text('완료'), findsNothing);
    expect(prefs.containsKey('board_true'), isFalse);
    await tester.longPress(find.byKey(const ValueKey('clock')).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('위젯 삭제'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing saved board is preserved on upgrade without the onboarding flag', (tester) async {
    final prefs = await openBoard(tester, {'board_true': '[]'});
    expect(find.text('어떤 대시보드로 시작할까요?'), findsNothing);
    expect(BoardStore(prefs).load('default', true).tiles, isEmpty);
    expect(prefs.getBool('intro_seen'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
