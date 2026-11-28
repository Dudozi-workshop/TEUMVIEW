import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:teumview/skin.dart';
void main() {
  test('catalog IDs are unique and unknown IDs fall back', () {
    expect(SkinStyle.catalog.map((s) => s.id).toSet().length, 3);
    expect(SkinStyle.resolve('unknown').id, 'dark');
    expect(SkinStyle.resolve('oled').background, Colors.black);
  });
  test('light skin has light brightness', () {
    expect(SkinStyle.resolve('light').theme().brightness, Brightness.light);
  });
}
