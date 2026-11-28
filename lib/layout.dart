import 'dart:convert';

const widgetKinds = ['clock','date','weather','calendar','agenda','tasks','memo','battery','dday','photo'];

class Tile {
  const Tile(this.id, this.kind, this.x, this.y, this.w, this.h);
  final String id, kind;
  final int x,y,w,h;
  Tile change({int? x,int? y,int? w,int? h}) => Tile(id,kind,x??this.x,y??this.y,w??this.w,h??this.h);
  bool overlaps(Tile b) => x < b.x+b.w && x+w > b.x && y < b.y+b.h && y+h > b.y;
  Map<String,dynamic> toJson()=>{'id':id,'kind':kind,'x':x,'y':y,'w':w,'h':h};
  factory Tile.fromJson(Map<String,dynamic> m)=>Tile(m['id'] as String,m['kind'] as String,m['x'] as int,m['y'] as int,m['w'] as int,m['h'] as int);
}
class Board {
  Board(this.cols,this.rows,List<Tile> tiles): tiles=List.unmodifiable(tiles);
  final int cols,rows;
  final List<Tile> tiles;
  bool fits(Tile t)=>t.x>=0 && t.y>=0 && t.w>0 && t.h>0 && t.x+t.w<=cols && t.y+t.h<=rows && !tiles.any((b)=>b.id!=t.id && b.overlaps(t));
  Board? put(Tile t)=>fits(t)?Board(cols,rows,[...tiles.where((b)=>b.id!=t.id),t]):null;
  Board remove(String id)=>Board(cols,rows,tiles.where((t)=>t.id!=id).toList());
  String encode()=>jsonEncode(tiles.map((t)=>t.toJson()).toList());
  static Board defaults(bool wide)=>wide?Board(8,4,const [Tile('clock','clock',0,0,5,4),Tile('date','date',5,0,3,2)]):Board(4,8,const [Tile('clock','clock',0,0,4,4),Tile('date','date',0,4,4,2)]);
  static Board preset(bool wide, String kind) {
    final kinds = switch(kind) {
      'work' => ['clock','agenda','tasks','memo'],
      'desk' => ['clock','date','weather','battery'],
      'photo' => ['photo','clock','date','dday'],
      _ => <String>[],
    };
    if(kinds.isEmpty) return defaults(wide);
    if (kind == 'desk') {
      return wide ? Board(8, 4, const [
        Tile('preset_clock', 'clock', 0, 0, 4, 4),
        Tile('preset_date', 'date', 4, 0, 4, 2),
        Tile('preset_weather', 'weather', 4, 2, 2, 2),
        Tile('preset_battery', 'battery', 6, 2, 2, 2),
      ]) : Board(4, 8, const [
        Tile('preset_clock', 'clock', 0, 0, 4, 3),
        Tile('preset_date', 'date', 0, 3, 4, 2),
        Tile('preset_weather', 'weather', 0, 5, 2, 3),
        Tile('preset_battery', 'battery', 2, 5, 2, 3),
      ]);
    }
    return Board(wide?8:4,wide?4:8,[
      for(var i=0;i<kinds.length;i++)
        Tile('preset_${kinds[i]}',kinds[i],wide?(i%2)*4:0,wide?(i~/2)*2:i*2,4,2),
    ]);
  }
  static Board restore(String? raw,bool wide){
    final fallback=defaults(wide);
    if(raw==null)return fallback;
    try {
      var b=Board(fallback.cols,fallback.rows,[]);
      for(final m in jsonDecode(raw) as List){
        final t=Tile.fromJson(m as Map<String,dynamic>);
        if(b.tiles.any((a)=>a.id==t.id)||!widgetKinds.contains(t.kind))return fallback;
        final next=b.put(t); if(next==null)return fallback; b=next;
      }
      return b;
    } catch (_) {return fallback;}
  }
}
