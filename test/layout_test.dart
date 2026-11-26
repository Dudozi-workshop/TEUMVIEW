import 'package:flutter_test/flutter_test.dart';
import 'package:teumview/layout.dart';
void main(){
 test('reject overlap and bounds',(){final b=Board.defaults(true);expect(b.put(const Tile('a','date',0,0,1,1)),isNull);expect(b.put(const Tile('a','date',8,0,1,1)),isNull);});
 test('move and resize persist',(){final b=Board.defaults(true);final n=b.put(b.tiles.last.change(y:2))!;expect(Board.restore(n.encode(),true).tiles.last.y,2);});
 test('invalid storage falls back',(){expect(Board.restore('bad',false).tiles.length,2);});
 test('empty layout round trip',(){expect(Board.restore('[]',false).tiles,isEmpty);});
}
