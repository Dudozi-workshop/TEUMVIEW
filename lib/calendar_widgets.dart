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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final emptyText = !connected ? '캘린더 연결' : !selected ? '캘린더 선택' : '예정된 일정 없음';
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    String timeLabel(CalendarEvent event) {
      final start = event.displayStart;
      final day = DateTime(start.year, start.month, start.day);
      final date = day == today ? '오늘' : day == tomorrow ? '내일' : '${start.month}/${start.day}';
      final time = event.allDay ? '종일' : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      return '$date · $time';
    }
    void openSettings() {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CalendarSettingsPage(prefs: widget.prefs),
      ));
    }
    Widget menu({Widget? child}) => PopupMenuButton<String>(
      tooltip: '일정 옵션',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'refresh') update();
        if (value == 'settings') openSettings();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'refresh', enabled: connected && selected && !busy, child: const Text('일정 갱신')),
        const PopupMenuItem(value: 'settings', child: Text('캘린더 설정')),
      ],
      child: child,
    );
    return LayoutBuilder(builder: (context, size) {
      if (size.maxHeight < 70 || size.maxWidth < 100) {
        final summary = Align(alignment: Alignment.centerLeft, child: Text(
          events.isEmpty ? emptyText : '${timeLabel(events.first)}  ${events.first.title}',
          maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium,
        ));
        return widget.editing ? summary : menu(child: summary);
      }
      return ListView(padding: EdgeInsets.zero, children: [
        Row(children: [
          Expanded(child: Text('일정', style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant))),
          if (busy) const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!widget.editing) SizedBox(width: 44, height: 36, child: menu()),
        ]),
        if (error != null) Text(error!, style: theme.textTheme.bodySmall),
        if (events.isEmpty)
          Align(alignment: Alignment.centerLeft, child: !widget.editing && (!connected || !selected)
              ? TextButton(onPressed: openSettings, child: Text(emptyText))
              : Text(emptyText, style: theme.textTheme.bodyMedium))
        else for (var i = 0; i < events.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeLabel(events[i]), style: theme.textTheme.labelMedium?.copyWith(color: colors.primary)),
              Text(events[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: i == 0 ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium),
            ],
          )),
      ]);
    });
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
