import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'layout.dart';

class BoardStore {
  BoardStore(this.prefs);
  final SharedPreferences prefs;
  List<String> get ids => prefs.getStringList('dashboard_ids') ?? ['default'];
  String get active => ids.contains(prefs.getString('active_dashboard')) ? prefs.getString('active_dashboard')! : ids.first;
  String key(String id, bool wide) => id == 'default' ? 'board_$wide' : 'board_${id}_$wide';
  Board load(String id,bool wide) => Board.restore(prefs.getString(key(id,wide)),wide);
  Future<void> create() async {
    final id=DateTime.now().microsecondsSinceEpoch.toString();
    for(final wide in [false,true]) {
      final b=Board.defaults(wide);
      await prefs.setString(key(id,wide),Board(b.cols,b.rows,b.tiles.map((t)=>Tile('${id}_${t.id}',t.kind,t.x,t.y,t.w,t.h)).toList()).encode());
    }
    await prefs.setStringList('dashboard_ids',[...ids,id]);
    await select(id);
  }
  Future<void> select(String id) async {if(ids.contains(id)) await prefs.setString('active_dashboard',id);}
  String name(String id) => prefs.getString('board_name_$id') ?? 'Dashboard ${ids.indexOf(id)+1}';
  Future<void> rename(String id,String value) async {
    final label=value.trim();
    if(!ids.contains(id)||label.isEmpty||label.length>40) throw ArgumentError('Invalid name');
    if(!await prefs.setString('board_name_$id',label)) throw StateError('Save failed');
  }
  Future<void> delete(String id) async {
    final remaining=ids.where((x)=>x!=id).toList();
    if(!ids.contains(id)||remaining.isEmpty) throw StateError('Cannot delete dashboard');
    if(active==id) await select(remaining.first);
    if(!await prefs.setStringList('dashboard_ids',remaining)) throw StateError('Save failed');
    for(final wide in [false,true]) {await prefs.remove(key(id,wide));}
    await prefs.remove('board_name_$id');
  }
  bool allowed(String k)=>k.startsWith('board_')||k.startsWith('content_')||['dashboard_ids','active_dashboard','skin','night','awake','brightness','low_power','burnin','custom_skin'].contains(k);
  String export() => jsonEncode({'version':1,'settings':{for(final k in prefs.getKeys().where(allowed)) k:prefs.get(k)}});
  Future<void> restore(String raw) async {
    final root=jsonDecode(raw);
    if(root is! Map || root['version']!=1 || root['settings'] is! Map) throw const FormatException('Invalid backup');
    final data=Map<String,dynamic>.from(root['settings'] as Map);
    for(final e in data.entries){
      if(!allowed(e.key)) throw const FormatException('Unknown setting');
      final v=e.value;
      if(e.key=='dashboard_ids'){if(v is! List || v.isEmpty || v.any((x)=>x is! String || x.isEmpty) || v.toSet().length!=v.length) throw const FormatException('Invalid dashboards');}
      else if(e.key=='brightness'){if(v is! num || v<0.05 || v>1) throw const FormatException('Invalid brightness');}
      else if(['night','awake','burnin','low_power'].contains(e.key)){if(v is! bool) throw const FormatException('Invalid flag');}
      else if(v is! String) {throw const FormatException('Invalid value');}
    }
    final previous=export();
    try {await _apply(data);} catch (_) {await _apply(Map<String,dynamic>.from(jsonDecode(previous)['settings'] as Map));rethrow;}
  }
  Future<void> _apply(Map<String,dynamic> data) async {
    for(final k in prefs.getKeys().where(allowed).toList()){if(!await prefs.remove(k))throw StateError('Remove failed');}
    for(final e in data.entries){final v=e.value; final bool ok;
      if(v is String){ok=await prefs.setString(e.key,v);}else if(v is bool){ok=await prefs.setBool(e.key,v);}else if(v is num){ok=await prefs.setDouble(e.key,v.toDouble());}else{ok=await prefs.setStringList(e.key,List<String>.from(v as List));}
      if(!ok)throw StateError('Save failed');
    }
  }
}
