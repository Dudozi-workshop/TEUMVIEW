import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/custom_skin.dart';
import 'package:teumview/skin.dart';
void main(){
 test('custom skin round trip',(){const s=CustomSkin(accent:0xff80aaff,opacity:.4,radius:12,scale:1.2,font:'monospace');final r=CustomSkin.decode(s.encode());expect(r.opacity,.4);expect(r.radius,12);expect(r.scale,1.2);expect(r.font,'monospace');expect(r.apply(SkinStyle.resolve('dark')).accent.value,0xff80aaff);});
 test('invalid values bounded',(){final s=CustomSkin.decode('{"radius":99,"opacity":-1,"scale":5}');expect(s.radius,24);expect(s.opacity,0);expect(s.scale,1.3);});
 test('invalid json defaults',(){expect(CustomSkin.decode('bad').radius,8);});
}
