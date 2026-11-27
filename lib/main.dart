import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'file_backup.dart';
import 'dart:async';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:io';
import 'custom_skin.dart';
import 'skin.dart';
export 'skin.dart' show Skin;
import 'layout.dart';
import 'board_store.dart';
import 'display_policy.dart';
import 'dashboard_content.dart';
import 'calendar_widgets.dart';
import 'google_calendar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // OAuth failures must not prevent the offline dashboard from starting.
  try { await CalendarService.instance.initialize(); } catch (e) { debugPrint('Calendar init unavailable: $e'); }
  runApp(Teumview(prefs: prefs));
}



class Teumview extends StatefulWidget {
  const Teumview({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<Teumview> createState() => _TeumviewState();
}

class _TeumviewState extends State<Teumview> {
  late Skin skin = Skin.values.firstWhere((s) => s.name == widget.prefs.getString('skin'), orElse: () => Skin.dark);
  late bool night = widget.prefs.getBool('night') ?? false;
  Timer? nightTimer;
  late CustomSkin custom=CustomSkin.decode(widget.prefs.getString('custom_skin')); 
  int revision=0;
  late double? brightness=widget.prefs.getDouble('brightness');
  late bool lowPower=widget.prefs.getBool('low_power')??false;
  Future<void> applyBrightness() async {
    try {
      if(brightness==null){await ScreenBrightness.instance.resetApplicationScreenBrightness();}
      else {await ScreenBrightness.instance.setApplicationScreenBrightness(brightness!.clamp(0.05,1.0).toDouble());}
    } catch(e) {debugPrint('Brightness unavailable: $e');}
  }

  late final store=BoardStore(widget.prefs);
  late bool burnin=widget.prefs.getBool('burnin')??false;
  late bool awake = widget.prefs.getBool('awake') ?? false;
  @override
  void initState() { super.initState(); applyBrightness(); WakelockPlus.toggle(enable: awake); nightTimer=Timer.periodic(const Duration(minutes:1),(_){if(mounted&&night)setState((){});}); }
  @override void dispose(){nightTimer?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context) {
    final activeSkin=night&&isNight(DateTime.now().hour,22,7)?Skin.oled:skin;
    final isNightActive=night&&isNight(DateTime.now().hour,22,7);
    final effective=isNightActive?const CustomSkin():custom;
    final style = effective.apply(SkinStyle.resolve(activeSkin.name));
    final surface = style.surface;
    return MaterialApp(debugShowCheckedModeBanner: false, theme: style.theme().copyWith(textTheme:style.theme().textTheme.apply(fontFamily:effective.font=='system'?null:effective.font)), builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(effective.scale)),child:child!), home: Builder(builder: (context) => Dashboard(key:ValueKey(revision), prefs: widget.prefs, surface: surface.withOpacity(style.cardOpacity), radius:style.radius, photo:effective.photo, burnin:burnin, lowPower:lowPower, onSettings: () => showModalBottomSheet<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const ListTile(title: Text('설정',style:TextStyle(fontSize:22,fontWeight:FontWeight.w600))),const SettingsSection('디스플레이'),
SwitchListTile(title:const Text('저전력 모드'),subtitle:const Text('시계 갱신을 분 단위로 변경'),value:lowPower,onChanged:(v){setState(()=>lowPower=v);update((){});widget.prefs.setBool('low_power',v);}),
ListTile(title:Text(brightness==null?'시스템 밝기':'화면 밝기 ${(brightness!*100).round()}%'),subtitle:Slider(min:0.05,max:1,value:brightness??0.5,onChanged:(v){setState(()=>brightness=v);update((){});},onChangeEnd:(v)async{await widget.prefs.setDouble('brightness',v);await applyBrightness();}),trailing:IconButton(tooltip:'시스템 밝기 복원',icon:const Icon(Icons.restart_alt),onPressed:()async{setState(()=>brightness=null);update((){});await widget.prefs.remove('brightness');await applyBrightness();})), const SettingsSection('스킨'),ListTile(title:const Text('사용자 스킨'),onTap:()async{final result=await showModalBottomSheet<CustomSkin>(context:context,isScrollControlled:true,builder:(_)=>CustomSkinEditor(initial:custom));if(result!=null&&mounted){await widget.prefs.setString('custom_skin',result.encode());if(mounted)setState(()=>custom=result);}}), const SettingsSection('화면 보호'),SwitchListTile(title:const Text('번인 완화 위치 이동'),value:burnin,onChanged:(v){setState(()=>burnin=v);update((){});widget.prefs.setBool('burnin',v);}), const SettingsSection('외부 연동'),ListTile(title:const Text('Google Calendar'),subtitle:const Text('읽기 전용 · 일정 연동'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CalendarSettingsPage(prefs:widget.prefs)))), const SettingsSection('데이터 관리'),ListTile(title:const Text('백업 파일 저장'),onTap:()async{try{final raw=await FileBackup(store).export();await FilePicker.platform.saveFile(fileName:'teumview_backup.json',type:FileType.custom,allowedExtensions:['json'],bytes:Uint8List.fromList(utf8.encode(raw)));}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('백업 실패')));}}), ListTile(title:const Text('백업 파일 복원'),onTap:()async{final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('현재 설정을 덮어쓸까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('복원'))]));if(confirmed!=true||!context.mounted)return;try{final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json']);if(result==null)return;final path=result.files.single.path;if(path==null)throw const FormatException();final file=File(path);if(await file.length()>FileBackup.maxBytes*2)throw const FormatException();await FileBackup(store).restore(await file.readAsString());if(!mounted)return;setState((){revision++;brightness=widget.prefs.getDouble('brightness');lowPower=widget.prefs.getBool('low_power')??false;custom=CustomSkin.decode(widget.prefs.getString('custom_skin'));skin=Skin.values.firstWhere((s)=>s.name==widget.prefs.getString('skin'),orElse:()=>Skin.dark);night=widget.prefs.getBool('night')??false;awake=widget.prefs.getBool('awake')??false;burnin=widget.prefs.getBool('burnin')??false;});await applyBrightness();WakelockPlus.toggle(enable:awake);if(context.mounted)Navigator.pop(context);}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('복원 실패')));}}), const SettingsSection('기본 스킨'),for (final option in Skin.values) RadioListTile<Skin>(title: Text(SkinStyle.resolve(option.name).label), secondary: SkinPreview(style: SkinStyle.resolve(option.name)), value: option, groupValue: skin, onChanged: (value) { if (value == null) return; setState(() => skin = value); update(() {}); widget.prefs.setString('skin', value.name); }), const SettingsSection('프리미엄 스킨'),for(final premium in SkinStyle.premiumCatalog) ListTile(leading:SkinPreview(style:premium),title:Text(premium.label),subtitle:const Text('미리보기 · 출시 준비 중'),trailing:const Icon(Icons.lock_outline),onTap:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(premium.label),content:Column(mainAxisSize:MainAxisSize.min,children:[SkinPreview(style:premium),const SizedBox(height:12),const Text('영구 구매 상품으로 출시 예정입니다. 현재 결제는 지원하지 않습니다.')]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('닫기')),FilledButton(onPressed:(){Navigator.pop(ctx);Navigator.push(context,MaterialPageRoute(builder:(_)=>PremiumSkinDemo(style:premium)));},child:const Text('전체 화면 미리보기'))]))),const SettingsSection('화면 유지'),SwitchListTile(title: const Text('야간 OLED 모드 (22:00–07:00)'),value:night,onChanged:(value){setState(()=>night=value);update((){});widget.prefs.setBool('night',value);}), SwitchListTile(title: const Text('화면 항상 켜기'), value: awake, onChanged: (value) { setState(() => awake = value); update(() {}); widget.prefs.setBool('awake', value); WakelockPlus.toggle(enable: value); })]))))))));
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.prefs, required this.surface, required this.onSettings, required this.burnin,required this.lowPower,required this.radius,required this.photo});
  final SharedPreferences prefs;
  final Color surface;
  final double radius;
  final String? photo;
  final VoidCallback onSettings;
  final bool burnin,lowPower;
  @override
  State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
  late final store=BoardStore(widget.prefs);
  late String active=store.active;
  late final boards=<bool,Board>{for(final wide in [false,true]) wide:store.load(active,wide)};
  Future<void> switchBoard(String id) async {await store.select(id);if(!mounted)return;setState((){active=id;selected=null;preview=null;for(final wide in [false,true]){boards[wide]=store.load(id,wide);undo[wide]!.clear();redo[wide]!.clear();}});}
  Future<void> renameBoard() async {
    String value=store.name(active);
    final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('대시보드 이름 변경'),content:TextFormField(initialValue:value,maxLength:40,onChanged:(v)=>value=v),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('취소')),TextButton(onPressed:()=>Navigator.pop(ctx,value),child:const Text('저장'))]));
    if(result==null||result.trim().isEmpty||!mounted)return;
    await store.rename(active,result);if(mounted)setState((){});
  }
  Future<void> deleteBoard() async {
    final id=active;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('${store.name(id)}을(를) 삭제할까요?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('삭제'))]));
    if(yes!=true||!mounted)return;
    await store.delete(id);if(mounted)await switchBoard(store.active);
  }
  final undo=<bool,List<Board>>{false:[],true:[]};
  final redo=<bool,List<Board>>{false:[],true:[]};
  bool editing=false;
  Tile? preview;
  String? selected;
  DateTime now=DateTime.now();
  Timer? timer;
  @override
  void initState(){super.initState();if(!(widget.prefs.getBool('intro_seen')??false)){WidgetsBinding.instance.addPostFrameCallback((_)async{if(!mounted)return;await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('나만의 대시보드, 틈뷰'),content:const Text('화면을 길게 누르면 편집할 수 있어요. 추천 템플릿에서 시작하거나 위젯을 자유롭게 배치해 보세요.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('시작하기'))]));await widget.prefs.setBool('intro_seen',true);});}timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted){final next=DateTime.now();if(!widget.lowPower||next.minute!=now.minute||next.hour!=now.hour||next.day!=now.day)setState(()=>now=next);}});}
  @override
  void dispose(){timer?.cancel();super.dispose();}
  void save(bool wide,Board b){setState(()=>boards[wide]=b);widget.prefs.setString(store.key(active,wide),b.encode());}
  void commit(bool wide,Board? b){if(b!=null&&b.encode()==boards[wide]!.encode())return;if(b==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('배치 공간이 부족하거나 다른 위젯과 겹칩니다.'),duration:Duration(seconds:1)));return;}undo[wide]!.add(boards[wide]!);redo[wide]!.clear();save(wide,b);}
  void history(bool wide,bool back){final from=(back?undo:redo)[wide]!;final to=(back?redo:undo)[wide]!;if(from.isEmpty)return;to.add(boards[wide]!);save(wide,from.removeLast());}
  void add(bool wide,String kind){final b=boards[wide]!;for(var y=0;y<b.rows;y++){for(var x=0;x<b.cols;x++){final t=Tile(DateTime.now().microsecondsSinceEpoch.toString(),kind,x,y,2,2);final next=b.put(t);if(next!=null){commit(wide,next);return;}}}ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('위젯을 추가할 공간이 없습니다.')));}
  String two(int n)=>n.toString().padLeft(2,'0');
  @override
  Widget build(BuildContext context)=>Scaffold(body:Stack(fit:StackFit.expand,children:[if(widget.photo!=null) Image.file(File(widget.photo!),fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),if(widget.photo!=null) const ColoredBox(color:Color(0x55000000)),SafeArea(child:LayoutBuilder(builder:(context,outer){
    final wide=outer.maxWidth>outer.maxHeight;
    final b=boards[wide]!;
    return Column(children:[if(editing) SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      TextButton(onPressed:()=>setState((){editing=false;selected=null;preview=null;undo[false]!.clear();undo[true]!.clear();redo[false]!.clear();redo[true]!.clear();}),child:const Text('완료')),
      IconButton(tooltip:'실행 취소',onPressed:undo[wide]!.isEmpty?null:()=>history(wide,true),icon:const Icon(Icons.undo)),
      IconButton(tooltip:'다시 실행',onPressed:redo[wide]!.isEmpty?null:()=>history(wide,false),icon:const Icon(Icons.redo)),
      IconButton(tooltip:'위젯 추가',onPressed:() async {final kind=await showModalBottomSheet<String>(context:context,isScrollControlled:true,builder:(_)=>const WidgetPicker());if(kind!=null&&mounted)add(wide,kind);},icon:const Icon(Icons.add)),
      PopupMenuButton<String>(tooltip:'대시보드',onSelected:(id)async{if(id=='rename'){await renameBoard();}else if(id=='delete'){await deleteBoard();}else if(id=='+'){await store.create();await switchBoard(store.active);}else{await switchBoard(id);}},itemBuilder:(_)=>[for(final id in store.ids) PopupMenuItem(value:id,child:Text('${store.name(id)}${id==active?" ✓":""}')),const PopupMenuItem(value:'+',child:Text('새 대시보드')),const PopupMenuItem(value:'rename',child:Text('이름 변경')),if(store.ids.length>1)const PopupMenuItem(value:'delete',child:Text('삭제'))],icon:const Icon(Icons.dashboard_customize)),
      IconButton(tooltip:'설정',onPressed:widget.onSettings,icon:const Icon(Icons.settings)),
      IconButton(tooltip:'추천 템플릿',icon:const Icon(Icons.space_dashboard_outlined),onPressed:()async{
        final choice=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const ListTile(title:Text('현재 방향의 배치를 변경합니다. 실행 취소 가능')),
          for(final entry in const {'desk':'탁상 디스플레이','work':'업무 일정','photo':'사진 중심'}.entries)
            ListTile(title:Text(entry.value),onTap:()=>Navigator.pop(ctx,entry.key)),
        ])));
        if(choice==null||!mounted)return;
        final p=Board.preset(wide,choice);
        commit(wide,Board(p.cols,p.rows,p.tiles.map((t)=>Tile('${active}_${wide}_${DateTime.now().microsecondsSinceEpoch}_${t.id}',t.kind,t.x,t.y,t.w,t.h)).toList()));
      }),
      IconButton(tooltip:'배치 초기화',onPressed:()=>commit(wide,Board(boards[wide]!.cols,boards[wide]!.rows,Board.defaults(wide).tiles.map((t)=>active=='default'?t:Tile('${active}_${t.id}',t.kind,t.x,t.y,t.w,t.h)).toList())),icon:const Icon(Icons.restart_alt)),
    ])),Expanded(child:Padding(padding:EdgeInsets.fromLTRB(8+(widget.burnin&&!editing?now.minute%3*2.0:0),8,8,8+(widget.burnin&&!editing?now.minute%3*2.0:0)),child:LayoutBuilder(builder:(context,c){
      final cw=c.maxWidth/b.cols,ch=c.maxHeight/b.rows;
      return GestureDetector(behavior:HitTestBehavior.opaque,onLongPress:()=>setState(()=>editing=true),child:Stack(fit:StackFit.expand,children:[
        if(editing) for(var y=0;y<b.rows;y++)for(var x=0;x<b.cols;x++) Positioned(left:x*cw,top:y*ch,width:cw,height:ch,child:IgnorePointer(child:Container(margin:const EdgeInsets.all(2),decoration:BoxDecoration(border:Border.all(color:Theme.of(context).dividerColor.withAlpha(60)))))),
        for(final t in b.tiles) Positioned(key:ValueKey(t.id),left:t.x*cw,top:t.y*ch,width:t.w*cw,height:t.h*ch,child:TileView(tile:t,editing:editing,selected:selected==t.id,surface:widget.surface,radius:widget.radius,content:DashboardContent(key:ValueKey(t.id),tile:t,prefs:widget.prefs,now:now,editing:editing),onSelect:()=>setState(()=>selected=t.id),onPreview:(d,resize)=>setState(()=>preview=d==null?null:resize?t.change(w:t.w+(d.dx/cw).round(),h:t.h+(d.dy/ch).round()):t.change(x:t.x+(d.dx/cw).round(),y:t.y+(d.dy/ch).round())),onMove:(d)=>commit(wide,boards[wide]!.put(t.change(x:t.x+(d.dx/cw).round(),y:t.y+(d.dy/ch).round()))),onResize:(d)=>commit(wide,boards[wide]!.put(t.change(w:t.w+(d.dx/cw).round(),h:t.h+(d.dy/ch).round()))),onDelete:()=>commit(wide,boards[wide]!.remove(t.id)))),
        if(editing&&preview!=null&&preview!.w>0&&preview!.h>0) Positioned(left:preview!.x*cw,top:preview!.y*ch,width:preview!.w*cw,height:preview!.h*ch,child:IgnorePointer(child:Container(decoration:BoxDecoration(color:(b.fits(preview!)?Colors.green:Colors.red).withAlpha(45),border:Border.all(color:b.fits(preview!)?Colors.green:Colors.red,width:2)))))
      ]));
    }))) ]);
  }))]));
}
class TileView extends StatefulWidget {
  const TileView({super.key,required this.tile,required this.editing,required this.selected,required this.surface,required this.radius,required this.content,required this.onSelect,required this.onMove,required this.onResize,required this.onPreview,required this.onDelete});
  final Tile tile;final bool editing,selected;final Color surface;final double radius;final Widget content;
  final VoidCallback onSelect,onDelete;final ValueChanged<Offset> onMove,onResize;
  final void Function(Offset?,bool) onPreview;
  @override State<TileView> createState()=>_TileViewState();
}
class _TileViewState extends State<TileView>{
  Offset delta=Offset.zero;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(4),child:GestureDetector(onTap:widget.editing?widget.onSelect:null,onPanStart:widget.editing?(_){widget.onSelect();setState(()=>delta=Offset.zero);}:null,onPanUpdate:widget.editing?(d){delta+=d.delta;widget.onPreview(delta,false);}:null,onPanEnd:widget.editing?(_){widget.onPreview(null,false);widget.onMove(delta);setState(()=>delta=Offset.zero);}:null,onPanCancel:(){widget.onPreview(null,false);setState(()=>delta=Offset.zero);},child:Transform.translate(offset:Offset.zero,child:Container(decoration:BoxDecoration(color:widget.surface,borderRadius:BorderRadius.circular(widget.radius),border:widget.editing&&widget.selected?Border.all(color:Theme.of(context).colorScheme.primary):null),child:Stack(children:[Positioned.fill(child:LayoutBuilder(builder:(context,constraints){final shortest=constraints.biggest.shortestSide;final inset=(shortest*0.08).clamp(4.0,16.0).toDouble();return Padding(padding:EdgeInsets.all(inset),child:widget.content);})),if(widget.editing&&widget.selected)...[Positioned(top:0,right:0,child:IconButton(tooltip:'위젯 삭제',onPressed:widget.onDelete,icon:const Icon(Icons.close,size:18))),Positioned(bottom:0,right:0,child:ResizeHandle(onResize:widget.onResize,onPreview:(d)=>widget.onPreview(d,true)))]])))));
}
class ResizeHandle extends StatefulWidget{
  const ResizeHandle({super.key,required this.onResize,required this.onPreview});final ValueChanged<Offset> onResize;final ValueChanged<Offset?> onPreview;
  @override State<ResizeHandle> createState()=>_ResizeHandleState();
}
class _ResizeHandleState extends State<ResizeHandle>{Offset delta=Offset.zero;@override Widget build(BuildContext context)=>GestureDetector(behavior:HitTestBehavior.opaque,onPanStart:(_)=>delta=Offset.zero,onPanUpdate:(d){delta+=d.delta;widget.onPreview(delta);},onPanEnd:(_){widget.onPreview(null);widget.onResize(delta);},onPanCancel:()=>widget.onPreview(null),child:const SizedBox(width:48,height:48,child:Icon(Icons.open_in_full,size:18)));}

class WidgetPicker extends StatelessWidget {
  const WidgetPicker({super.key});
  static const icons = <String, IconData>{
    'clock': Icons.schedule, 'date': Icons.today, 'weather': Icons.wb_sunny_outlined,
    'calendar': Icons.calendar_month, 'agenda': Icons.event_note, 'tasks': Icons.checklist,
    'memo': Icons.notes, 'battery': Icons.battery_full, 'dday': Icons.flag_outlined,
    'photo': Icons.image_outlined,
  };
  static const samples = <String, String>{
    'clock':'09:41', 'date':'11월 26일', 'weather':'18° · 맑음',
    'calendar':'월 화 수 목 금', 'agenda':'09:00 일정', 'tasks':'할 일 2/4',
    'memo':'오늘의 메모', 'battery':'85%', 'dday':'D-7', 'photo':'사진',
  };
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(child: FractionallySizedBox(heightFactor: 0.8, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20,16,12,12), child: Row(children:[
          Expanded(child: Text('위젯 추가', style: theme.textTheme.titleLarge)),
          IconButton(tooltip:'닫기',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
        ])),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16,0,16,16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:200,mainAxisExtent:124,crossAxisSpacing:10,mainAxisSpacing:10),
          itemCount: widgetKinds.length,
          itemBuilder:(context,index){
            final kind=widgetKinds.elementAt(index);
            return Material(color:theme.colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12),clipBehavior:Clip.antiAlias,
              child:InkWell(onTap:()=>Navigator.pop(context,kind),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(icons[kind]??Icons.widgets_outlined,size:20,color:theme.colorScheme.primary),
                const Spacer(),
                FittedBox(fit:BoxFit.scaleDown,child:Text(samples[kind]??'',style:theme.textTheme.titleLarge)),
                const SizedBox(height:4),
                Text(widgetLabels[kind]??kind,style:theme.textTheme.labelMedium),
              ]))));
          },
        )),
      ],
    )));
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection(this.label,{super.key});
  final String label;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,20,16,6),child:Align(alignment:Alignment.centerLeft,child:Text(label,style:Theme.of(context).textTheme.labelLarge?.copyWith(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.w600))));
}

class PremiumSkinDemo extends StatelessWidget {
  const PremiumSkinDemo({super.key,required this.style});
  final SkinStyle style;
  @override
  Widget build(BuildContext context) {
    return Theme(data:style.theme(),child:Scaffold(backgroundColor:style.background,
      appBar:AppBar(title:Text(style.label),backgroundColor:style.background),
      body:SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        const Text('미리보기 · 샘플 데이터'),
        const SizedBox(height:12),
        Expanded(flex:3,child:_tile('MONDAY','09:41',48)),
        const SizedBox(height:8),
        Expanded(flex:2,child:Row(children:[
          Expanded(child:_tile('날씨','18°',32)),
          const SizedBox(width:8),
          Expanded(child:_tile('일정','D-7',32)),
        ])),
        const SizedBox(height:8),
        Expanded(flex:2,child:_tile('오늘의 일정','09:00  미팅',22)),
      ])))));
  }
  Widget _tile(String label,String value,double size)=>Container(
    width:double.infinity,
    decoration:BoxDecoration(color:style.surface.withValues(alpha:style.cardOpacity),borderRadius:BorderRadius.circular(style.radius)),
    padding:const EdgeInsets.all(12),
    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Text(label,style:TextStyle(color:style.accent)),
      Flexible(child:FittedBox(fit:BoxFit.scaleDown,child:Text(value,style:TextStyle(fontSize:size,color:style.brightness==Brightness.dark?Colors.white:Colors.black87)))),
    ]),
  );
}
