import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/main.dart';
void main() {
  test('built-in skin identifiers are stable', () {
    expect(Skin.values.map((s) => s.name).toList(), ['dark', 'light', 'oled']);
  });
}
