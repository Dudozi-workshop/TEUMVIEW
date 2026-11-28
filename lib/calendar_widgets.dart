import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_calendar_service.dart';

class AgendaPanel extends StatefulWidget {
  const AgendaPanel({super.key,required this.prefs,required this.editing});
  final SharedPreferences prefs;
  final bool editing;
  @override State<AgendaPanel> createState()=>_AgendaPanelState();
}
class _AgendaPanelState extends State<AgendaPanel> {
  final service=CalendarService.instance;
  bool busy=false;
  String? error;
  @override void initState(){super.initState();service.changes.addListener(changed);}
  @override void dispose(){service.changes.removeListener(changed);super.dispose();}
  void changed(){if(mounted)setState((){});}
  Future<void> update() async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try {await service.refresh(widget.prefs);}
    catch(_){if(mounted)setState(()=>error='갱신 실패 · 저장된 일정을 표시합니다');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context) {
    final now=DateTime.now();
    final end=DateTime(now.year,now.month,now.day).add(const Duration(days:2));
    final events=service.cached(widget.prefs).where((e)=>e.start.isBefore(end)&&e.end.isAfter(now)).take(6).toList();
    final connected=service.account!=null;
    final selected=service.selected(widget.prefs).isNotEmpty;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Text('일정',style:Theme.of(context).textTheme.labelSmall),const Spacer(),
        if(busy)const SizedBox(width:12,height:12,child:CircularProgressIndicator(strokeWidth:1.5)),
        if(!widget.editing) IconButton(tooltip:'일정 갱신',visualDensity:VisualDensity.compact,onPressed:connected&&selected?update:null,icon:const Icon(Icons.refresh,size:18)),
        if(!widget.editing)IconButton(tooltip:'캘린더 설정',visualDensity:VisualDensity.compact,onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CalendarSettingsPage(prefs:widget.prefs))),icon:const Icon(Icons.tune,size:18)),
      ]),
      if(error!=null)Text(error!,style:Theme.of(context).textTheme.labelSmall),
      Expanded(child:events.isEmpty?Center(child:Text(!connected?'Google Calendar 연결 필요':!selected?'표시할 캘린더를 선택하세요':'예정된 일정 없음',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)):
        ListView.builder(padding:EdgeInsets.zero,itemCount:events.length,itemBuilder:(ctx,index){final e=events[index];
          final start = e.displayStart;
          final date='${start.month}/${start.day}';
          final hour='${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}';
          return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            SizedBox(width:72,child:Text('$date ${e.allDay?'종일':hour}',style:Theme.of(context).textTheme.labelSmall)),
            Expanded(child:Text(e.title,maxLines:2,overflow:TextOverflow.ellipsis))]));
        })),
    ]);
  }
}

class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({super.key,required this.prefs});
  final SharedPreferences prefs;
  @override State<CalendarSettingsPage> createState()=>_CalendarSettingsPageState();
}
class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  final service=CalendarService.instance;
  List<CalendarChoice> calendars=[];
  bool busy=false;
  String? message;
  @override void initState(){super.initState();service.changes.addListener(updateView);if(service.account!=null)loadCalendars();}
  @override void dispose(){service.changes.removeListener(updateView);super.dispose();}
  void updateView(){if(mounted)setState((){});}
  Future<void> task(Future<void> Function() action) async {
    if(busy)return;
    setState((){busy=true;message=null;});
    try {await action();}
    catch(e){if(mounted)setState(()=>message='작업 실패. Google 계정·동의 화면·네트워크 설정을 확인하세요.');}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> loadCalendars() async => task(()async {
    final result=await service.listCalendars();
    if(mounted)setState(()=>calendars=result);
  });
  Future<void> connect() async => task(()async {
    await service.connect();
    final result=await service.listCalendars();
    if(mounted)setState(()=>calendars=result);
  });
  Future<void> disconnect() async {
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Google Calendar 연결 해제'),content:const Text('기기에 저장된 일정 캐시와 선택 목록도 삭제됩니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('연결 해제'))]));
    if(confirm!=true)return;
    await task(()async{await service.disconnect(widget.prefs);if(mounted)setState(()=>calendars=[]);});
  }
  @override Widget build(BuildContext context) {
    final selected=service.selected(widget.prefs);
    final account=service.account;
    final updated=service.lastUpdated(widget.prefs);
    return Scaffold(appBar:AppBar(title:const Text('Google Calendar')),body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('일정 읽기 전용 · 데이터는 이 기기에만 캐시됩니다.'),
      const SizedBox(height:10),
      if(busy)const LinearProgressIndicator(),
      if(message!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(message!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(account==null)FilledButton(onPressed:busy?null:connect,child:const Text('Google 계정 연결'))
      else ...[
        Text(account.email,style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:10),
        Row(children:[OutlinedButton(onPressed:busy?null:loadCalendars,child:const Text('캘린더 목록 갱신')),const SizedBox(width:8),TextButton(onPressed:busy?null:disconnect,child:const Text('연결 해제'))]),
        if(calendars.isEmpty)const Padding(padding:EdgeInsets.all(8),child:Text('캘린더 목록을 불러와 주세요.')),
        for(final cal in calendars)CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text(cal.label),subtitle:cal.primary?const Text('기본 캘린더'):null,value:selected.contains(cal.id),onChanged:busy?null:(v)async{
          final next=selected.toSet();if(v==true){next.add(cal.id);}else{next.remove(cal.id);}
          await service.saveSelected(widget.prefs,next.toList());
          if(next.isNotEmpty){await task(()=>service.refresh(widget.prefs).then((_){ }));}
          else {await widget.prefs.remove(CalendarService.cacheKey);service.changes.value++;}
        }),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:busy||selected.isEmpty?null:()=>task(()=>service.refresh(widget.prefs).then((_){ })),icon:const Icon(Icons.sync),label:const Text('일정 새로고침')),
        if(updated!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text('마지막 동기화: $updated',style:Theme.of(context).textTheme.bodySmall)),
      ],
    ]));
  }
}
