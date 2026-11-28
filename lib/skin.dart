import 'package:flutter/material.dart';

enum Skin { dark, light, oled }

class SkinStyle {
  const SkinStyle(this.id, this.label, this.background, this.surface, this.brightness, {this.accent = const Color(0xff86a873), this.radius = 8, this.cardOpacity = 1});
  final String id, label;
  final Color background, surface, accent;
  final Brightness brightness;
  final double radius, cardOpacity;
  static const catalog = [
    SkinStyle('dark', '다크', Color(0xff191a1c), Color(0xff25272a), Brightness.dark),
    SkinStyle('light', '라이트', Color(0xfff5f5f3), Color(0xffeaeae7), Brightness.light),
    SkinStyle('oled', 'OLED', Colors.black, Color(0xff111111), Brightness.dark),
  ];
  static const premiumCatalog = [
    SkinStyle('sage_glass', '세이지 글래스', Color(0xffdce8df), Color(0xfff1f6ef), Brightness.light, accent: Color(0xff739b83), radius: 16, cardOpacity: .92),
    SkinStyle('midnight_blue', '미드나이트 블루', Color(0xff101827), Color(0xff202e43), Brightness.dark, accent: Color(0xff8da9e6), radius: 12),
  ];
  static const premiumProducts = {'sage_glass':'teumview_skin_sage_glass','midnight_blue':'teumview_skin_midnight_blue'};
  static SkinStyle resolve(String? id) => catalog.firstWhere((s) => s.id == id, orElse: () => catalog.first);
  // Only verified store entitlements may unlock a premium style.
  static SkinStyle resolveEntitled(String? id, Set<String> verifiedProducts) {
    for (final style in premiumCatalog) {
      if (style.id == id && verifiedProducts.contains(premiumProducts[style.id])) return style;
    }
    return resolve(id);
  }
  ThemeData theme({Color? accentOverride}) => ThemeData(useMaterial3: true, brightness: brightness, scaffoldBackgroundColor: background, colorScheme: ColorScheme.fromSeed(seedColor: accentOverride ?? accent, brightness: brightness));
}

class SkinPreview extends StatelessWidget {
  const SkinPreview({super.key, required this.style});
  final SkinStyle style;
  @override
  Widget build(BuildContext context) {
    final ink = style.brightness == Brightness.dark ? Colors.white : Colors.black87;
    Widget tile(Widget child) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.surface.withValues(alpha: style.cardOpacity),
        borderRadius: BorderRadius.circular((style.radius / 2).clamp(0, 8).toDouble())),
      child: child,
    );
    return Container(width: 112, height: 64, padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ink.withValues(alpha: 0.12))),
      child: Row(children: [
        Expanded(flex: 3, child: tile(Text('09:41', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: ink)))),
        const SizedBox(width: 4),
        Expanded(flex: 2, child: Column(children: [
          Expanded(child: tile(Text('18°', style: TextStyle(fontSize: 11, color: ink)))),
          const SizedBox(height: 4),
          Expanded(child: tile(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.circle, size: 5, color: style.accent),
            const SizedBox(width: 3),
            Text('D-7', style: TextStyle(fontSize: 9, color: ink)),
          ]))),
        ])),
      ]),
    );
  }
}
