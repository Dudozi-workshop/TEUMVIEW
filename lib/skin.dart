import 'package:flutter/material.dart';

enum Skin { dark, light, oled }

class SkinStyle {
  const SkinStyle(this.id, this.label, this.background, this.surface, this.brightness, {this.accent = const Color(0xff86a873), this.radius = 8, this.cardOpacity = 1});
  final String id, label;
  final Color background, surface, accent;
  final Brightness brightness;
  final double radius, cardOpacity;
  static const catalog = [
    SkinStyle('dark', 'Dark', Color(0xff191a1c), Color(0xff25272a), Brightness.dark),
    SkinStyle('light', 'Light', Color(0xfff5f5f3), Color(0xffeaeae7), Brightness.light),
    SkinStyle('oled', 'OLED', Colors.black, Color(0xff111111), Brightness.dark),
  ];
  static SkinStyle resolve(String? id) => catalog.firstWhere((s) => s.id == id, orElse: () => catalog.first);
  ThemeData theme({Color? accentOverride}) => ThemeData(useMaterial3: true, brightness: brightness, scaffoldBackgroundColor: background, colorScheme: ColorScheme.fromSeed(seedColor: accentOverride ?? accent, brightness: brightness));
}

class SkinPreview extends StatelessWidget {
  const SkinPreview({super.key, required this.style});
  final SkinStyle style;
  @override Widget build(BuildContext context) => Container(width: 92, height: 52, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(6)), child: Row(children: [Expanded(child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: style.surface.withOpacity(style.cardOpacity), borderRadius: BorderRadius.circular(style.radius.clamp(0,12).toDouble())), child: Text('09:41', style: TextStyle(fontSize: 13, color: style.brightness == Brightness.dark ? Colors.white : Colors.black)))), const SizedBox(width: 4), Expanded(child: Column(children: [Expanded(child: Container(decoration: BoxDecoration(color: style.surface, borderRadius: BorderRadius.circular(3)))), const SizedBox(height: 3), Expanded(child: Container(decoration: BoxDecoration(color: style.accent, borderRadius: BorderRadius.circular(3))))]))]));
}
