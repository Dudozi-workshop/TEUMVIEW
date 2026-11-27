import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/layout.dart';
import 'package:teumview/skin.dart';

void main() {
  test('presets fit both orientations and survive serialization', () {
    for(final wide in [false,true]) {
      for(final kind in ['desk','work','photo']) {
        final b=Board.preset(wide,kind);
        expect(b.tiles.length,4);
        expect(b.tiles.every(b.fits),isTrue);
        expect(Board.restore(b.encode(),wide).encode(),b.encode());
      }
    }
  });
  test('premium products are distinct from free skins', () {
    expect(SkinStyle.premiumCatalog.length,2);
    expect(SkinStyle.premiumProducts.values.toSet().length,2);
    for(final s in SkinStyle.premiumCatalog) {
      expect(SkinStyle.premiumProducts.containsKey(s.id),isTrue);
      expect(SkinStyle.catalog.any((f)=>f.id==s.id),isFalse);
    }
  });
}
