import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'board_store.dart';

class FileBackup {
  FileBackup(this.store);
  final BoardStore store;
  static const maxBytes = 40 * 1024 * 1024;
  Future<String> export() async {
    final root = jsonDecode(store.export()) as Map;
    final settings = root['settings'] as Map;
    final assets = <String,String>{};
    final dir = await getApplicationDocumentsDirectory();
    var total = 0;
    Future<String> pack(String path) async {
      final file = File(path);
      if (!await file.exists()) throw const FormatException('Missing photo');
      final real = await file.resolveSymbolicLinks();
      final base = await dir.resolveSymbolicLinks();
      if (!real.startsWith('$base/')) throw const FormatException('External photo');
      total += await file.length();
      if (total > maxBytes) throw const FormatException('Backup too large');
      final id = 'asset_${assets.length}';
      assets[id] = base64Encode(await file.readAsBytes());
      return id;
    }
    for (final key in settings.keys.toList()) {
      final value = settings[key];
      if (key.toString().startsWith('content_') && value is String && (value.startsWith('${dir.path}/photo_') || value.startsWith('${dir.path}/restore_'))) {
        settings[key] = {'asset':await pack(value)};
      } else if (key == 'custom_skin' && value is String) {
        final skin = jsonDecode(value) as Map;
        if (skin['photo'] is String) skin['photo'] = {'asset':await pack(skin['photo'] as String)};
        settings[key] = jsonEncode(skin);
      }
    }
    return jsonEncode({'version':2,'settings':settings,'assets':assets});
  }
  Future<void> restore(String raw) async {
    if (raw.length > maxBytes * 2) throw const FormatException('Backup too large');
    final root = jsonDecode(raw) as Map;
    if (root['version'] == 1) { await store.restore(raw); return; }
    if (root['version'] != 2 || root['assets'] is! Map || root['settings'] is! Map) throw const FormatException('Invalid backup');
    final assets = root['assets'] as Map;
    final settings = Map<String,dynamic>.from(root['settings'] as Map);
    final dir = await getApplicationDocumentsDirectory();
    final staging = await dir.createTemp('restore_');
    var total = 0;
    final paths = <String,String>{};
    Future<String> unpack(dynamic ref) async {
      if (ref is! Map || ref['asset'] is! String) throw const FormatException('Invalid asset');
      final id = ref['asset'] as String;
      if (paths.containsKey(id)) return paths[id]!;
      final encoded = assets[id];
      if (encoded is! String) throw const FormatException('Missing asset');
      final bytes = base64Decode(encoded);
      total += bytes.length;
      if (total > maxBytes || bytes.isEmpty) throw const FormatException('Invalid asset size');
      final file = File('${staging.path}/photo_${paths.length}');
      await file.writeAsBytes(bytes, flush:true);
      return paths[id] = file.path;
    }
    try {
      for (final key in settings.keys.toList()) {
        final value = settings[key];
        if (key.startsWith('content_') && value is Map) {settings[key] = await unpack(value);}
        else if (key == 'custom_skin' && value is String) {
          final skin = jsonDecode(value) as Map;
          if (skin['photo'] is Map) skin['photo'] = await unpack(skin['photo']);
          else if (skin['photo'] != null) throw const FormatException('Invalid photo reference');
          settings[key] = jsonEncode(skin);
        }
      }
      await store.restore(jsonEncode({'version':1,'settings':settings}));
    } catch (_) { await staging.delete(recursive:true); rethrow; }
  }
}
