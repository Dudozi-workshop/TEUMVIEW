import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'layout.dart';
import 'reading_card.dart';
import 'weather.dart';
import 'calendar_widgets.dart';

const widgetLabels = {'clock':'시계','date':'날짜','weather':'날씨','calendar':'캘린더','agenda':'일정','tasks':'할 일','memo':'메모','battery':'배터리','dday':'디데이','photo':'사진'};
class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key,required this.tile,required this.prefs,required this.now,required this.editing});
  final Tile tile; final SharedPreferences prefs; final DateTime now; final bool editing;
  @override State<DashboardContent> createState()=>_ContentState();
}
class _ContentState extends State<DashboardContent> {
  String get storageKey=>'content_${widget.tile.id}';
  String get saved=>widget.prefs.getString(storageKey)??'';
  int? level; BatteryState? batteryState; Timer? poll;
  final battery=Battery();
  WeatherReading? weather; bool weatherBusy=false; bool weatherError=false;
  Future<void> refreshWeather() async {
    final location = saved;
    final parts=location.split(','); if(parts.length!=2||weatherBusy)return;
    final lat=double.tryParse(parts[0]),lon=double.tryParse(parts[1]); if(lat==null||lon==null)return;
    setState(()=>weatherBusy=true);
    try {final result=await fetchWeather(lat,lon); if(mounted&&saved==location)setState((){weather=result;weatherError=false;});}
    catch(_){if(mounted && saved == location)setState(()=>weatherError=true);}
    finally {
      if (mounted) {
        setState(() => weatherBusy = false);
        if (saved != location) unawaited(refreshWeather());
      }
    }
  }
  @override void initState(){super.initState();if(widget.tile.kind=='battery'){refresh();poll=Timer.periodic(const Duration(seconds:30),(_)=>refresh());}else if(widget.tile.kind=='weather'){refreshWeather();poll=Timer.periodic(const Duration(minutes:15),(_)=>refreshWeather());}}
  Future<void> refresh() async {try {final l=await battery.batteryLevel;final s=await battery.batteryState;if(mounted)setState((){level=l;batteryState=s;});}catch(_){if(mounted)setState(()=>level=null);}}
  @override void dispose(){poll?.cancel();super.dispose();}
  Future<void> save(String value) async {await widget.prefs.setString(storageKey,value);if(mounted)setState((){});}
  Future<String?> prompt(String title, String initial) {
    var value = initial;
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextFormField(initialValue: initial, maxLines: 3, autofocus: true,
        onChanged: (text) => value = text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('저장')),
      ],
    ));
  }
  List<Map<String,dynamic>> get tasks {try{return (jsonDecode(saved) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}catch(_){return [];}}
  Future<void> pickPhoto() async {try{final picked=await ImagePicker().pickImage(source:ImageSource.gallery);if(picked==null)return;final dir=await getApplicationDocumentsDirectory();final file=await File(picked.path).copy('${dir.path}/photo_${widget.tile.id}_${DateTime.now().microsecondsSinceEpoch}');await save(file.path);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('사진을 불러오지 못했습니다.')));}}
  String two(int n)=>n.toString().padLeft(2,'0');
  Future<void> setWeatherLocation() async {
    final value = await prompt('위도, 경도', saved);
    if (value == null || !mounted) return;
    final parts = value.split(',');
    final lat = double.tryParse(parts.first.trim());
    final lon = parts.length == 2 ? double.tryParse(parts.last.trim()) : null;
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite ||
        lat.abs() > 90 || lon.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위도와 경도를 확인해 주세요. 예: 37.57, 126.98')));
      return;
    }
    await save('$lat,$lon');
    if (!mounted) return;
    setState(() { weather = null; weatherError = false; });
    await refreshWeather();
  }

  Future<void> weatherOptions() async {
    if (saved.isEmpty) {
      await setWeatherLocation();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        ListTile(title: const Text('날씨'), subtitle: Text('Open-Meteo · $saved')),
        ListTile(leading: const Icon(Icons.refresh), title: const Text('새로고침'),
          enabled: !weatherBusy, onTap: () => Navigator.pop(ctx, 'refresh')),
        ListTile(leading: const Icon(Icons.place_outlined), title: const Text('위치 설정'),
          enabled: !weatherBusy, onTap: () => Navigator.pop(ctx, 'location')),
      ])),
    );
    if (!mounted) return;
    if (action == 'location') await setWeatherLocation();
    if (action == 'refresh') await refreshWeather();
  }

  Widget panel(String title,List<Widget> children)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.labelMedium?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant,fontWeight:FontWeight.w500)),const SizedBox(height:8),Expanded(child:ListView(padding:EdgeInsets.zero,children:children))]);
  Widget action(String text,VoidCallback callback)=>Align(alignment:Alignment.centerLeft,child:TextButton(style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:4,vertical:4),minimumSize:const Size(48,48)),onPressed:widget.editing?null:callback,child:Text(text)));
  @override Widget build(BuildContext context){final now=widget.now;switch(widget.tile.kind){
    case 'clock':
      return ReadingCard(label: '현재 시각',
        value: '${two(now.hour)}:${two(now.minute)}', large: true);
    case 'date':
      final day = const ['월','화','수','목','금','토','일'][now.weekday - 1];
      return ReadingCard(label: '$day요일', icon: Icons.calendar_today_outlined,
        value: '${now.month}월 ${now.day}일');
    case 'weather':
      final reading = weather;
      final state = weatherBusy ? '갱신 중' : weatherError ? '갱신 실패' : '위치 설정';
      final detail = reading == null ? 'Open-Meteo' :
        '${reading.description} · ${weatherError ? '갱신 실패' : "${two(reading.fetchedAt.hour)}:${two(reading.fetchedAt.minute)} 갱신"} · Open-Meteo';
      return ReadingCard(label: '날씨', icon: Icons.thermostat_outlined,
        value: reading == null ? state : '${reading.temperature.round()}°',
        detail: detail, onTap: widget.editing ? null : weatherOptions);
    case 'agenda':return AgendaPanel(prefs:widget.prefs,editing:widget.editing);
    case 'calendar':final first=DateTime(now.year,now.month,1);final count=DateTime(now.year,now.month+1,0).day;return panel('${now.year}년 ${now.month}월',[for(var row=0;row<(count+first.weekday-1+6)~/7;row++) Row(children:[for(var col=0;col<7;col++) Expanded(child:Builder(builder:(_){final day=row*7+col-first.weekday+2;return Center(child:Text(day<1||day>count?'':'$day',style:TextStyle(fontSize:12,color:day==now.day?Theme.of(context).colorScheme.primary:null,fontWeight:day==now.day?FontWeight.bold:null)));}))])]);
    case 'memo':return panel('메모',[Text(saved.isEmpty?'메모 없음':saved),action('수정',()async{final v=await prompt('메모',saved);if(v!=null)await save(v);})]);
    case 'tasks':final items=tasks;return panel('할 일 ${items.where((e)=>e['done']==true).length}/${items.length}',[for(var i=0;i<items.length;i++) Row(children:[Checkbox(value:items[i]['done']==true,onChanged:widget.editing?null:(v){items[i]['done']=v;save(jsonEncode(items));}),Expanded(child:Text('${items[i]['text']}')),IconButton(onPressed:widget.editing?null:(){items.removeAt(i);save(jsonEncode(items));},icon:const Icon(Icons.close,size:16))]),action('추가',()async{final v=await prompt('할 일','');if(v!=null&&v.trim().isNotEmpty){items.add({'text':v.trim(),'done':false});await save(jsonEncode(items));}})]);
    case 'battery':
      final charging = batteryState == BatteryState.charging;
      return ReadingCard(label: charging ? '배터리 · 충전 중' : '배터리',
        icon: charging ? Icons.battery_charging_full : Icons.battery_std,
        value: level == null ? '확인 불가' : '$level%',
        fraction: level == null ? null : (level! / 100).clamp(0.0, 1.0).toDouble());
    case 'dday':final target=DateTime.tryParse(saved);final days=target==null?null:DateTime.utc(target.year,target.month,target.day).difference(DateTime.utc(now.year,now.month,now.day)).inDays;return panel('디데이',[Text(days==null?'목표일 미설정':days==0?'D-Day':days>0?'D-$days':'D+${-days}',style:Theme.of(context).textTheme.headlineMedium),action('목표일 설정',()async{final d=await showDatePicker(context:context,initialDate:now,firstDate:DateTime(1900),lastDate:DateTime(2100));if(d!=null)await save(d.toIso8601String());})]);
    case 'photo':return Column(children:[Expanded(child:saved.isEmpty?const Center(child:Text('사진 없음')):Image.file(File(saved),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('사진 없음'))),action('사진 선택',pickPhoto)]);
    default:return const SizedBox.shrink();
  }}
}
