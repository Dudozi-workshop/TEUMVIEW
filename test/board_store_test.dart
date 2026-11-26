import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teumview/board_store.dart';
void main(){
 test('rename and delete preserve remaining board and reject last deletion',() async {
 SharedPreferences.setMockInitialValues({});final p=await SharedPreferences.getInstance();final s=BoardStore(p);
 await s.create();final id=s.active;await s.rename(id,'Desk');expect(s.name(id),'Desk');
 await s.delete(id);expect(s.active,'default');expect(s.ids,['default']);
 await expectLater(s.delete('default'),throwsStateError);
 });
 test('new dashboard has isolated tile ids and preserves legacy board',() async {
 SharedPreferences.setMockInitialValues({});final p=await SharedPreferences.getInstance();final s=BoardStore(p);await s.create();expect(s.ids.length,2);expect(s.load(s.active,true).tiles.first.id,isNot(s.load('default',true).tiles.first.id));
 });
 test('backup round trip and invalid version rejection',() async {
 SharedPreferences.setMockInitialValues({'skin':'dark'});final p=await SharedPreferences.getInstance();final s=BoardStore(p);final backup=s.export();await p.setString('skin','light');await s.restore(backup);expect(p.getString('skin'),'dark');await expectLater(s.restore('{"version":2}'),throwsFormatException);expect(p.getString('skin'),'dark');
 });
}
