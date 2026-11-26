import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'layout.dart';
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
    final parts=saved.split(','); if(parts.length!=2||weatherBusy)return;
    final lat=double.tryParse(parts[0]),lon=double.tryParse(parts[1]); if(lat==null||lon==null)return;
    setState(()=>weatherBusy=true);
    try {final result=await fetchWeather(lat,lon); if(mounted&&saved==parts.join(','))setState((){weather=result;weatherError=false;});}
    catch(_){if(mounted)setState(()=>weatherError=true);}
    finally{if(mounted)setState(()=>weatherBusy=false);}
  }
  @override void initState(){super.initState();if(widget.tile.kind=='battery'){refresh();poll=Timer.periodic(const Duration(seconds:30),(_)=>refresh());}else if(widget.tile.kind=='weather'){refreshWeather();poll=Timer.periodic(const Duration(minutes:15),(_)=>refreshWeather());}}
  Future<void> refresh() async {try {final l=await battery.batteryLevel;final s=await battery.batteryState;if(mounted)setState((){level=l;batteryState=s;});}catch(_){if(mounted)setState(()=>level=null);}}
  @override void dispose(){poll?.cancel();super.dispose();}
  Future<void> save(String value) async {await widget.prefs.setString(storageKey,value);if(mounted)setState((){});}
  Future<String?> prompt(String title,String initial) async {final controller=TextEditingController(text:initial);final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:TextField(controller:controller,maxLines:3,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('취소')),TextButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('저장'))]));controller.dispose();return result;}
  List<Map<String,dynamic>> get tasks {try{return (jsonDecode(saved) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}catch(_){return [];}}
  Future<void> pickPhoto() async {try{final picked=await ImagePicker().pickImage(source:ImageSource.gallery);if(picked==null)return;final dir=await getApplicationDocumentsDirectory();final file=await File(picked.path).copy('${dir.path}/photo_${widget.tile.id}_${DateTime.now().microsecondsSinceEpoch}');await save(file.path);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('사진을 불러오지 못했습니다.')));}}
  String two(int n)=>n.toString().padLeft(2,'0');
  Widget large(String value)=>Align(alignment:Alignment.centerLeft,child:FittedBox(fit:BoxFit.scaleDown,child:Text(value,style:const TextStyle(fontSize:80,fontWeight:FontWeight.w500))));
  Widget panel(String title,List<Widget> children)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.labelSmall),const SizedBox(height:4),Expanded(child:ListView(padding:EdgeInsets.zero,children:children))]);
  Widget action(String text,VoidCallback callback)=>TextButton(onPressed:widget.editing?null:callback,child:Text(text));
  @override Widget build(BuildContext context){final now=widget.now;switch(widget.tile.kind){
    case 'clock':return large('${two(now.hour)}:${two(now.minute)}');
    case 'date':return large('${now.month}월 ${now.day}일 ${['월','화','수','목','금','토','일'][now.weekday-1]}');
    case 'weather':return panel('날씨',[if(weather!=null)...[Text('${weather!.temperature.round()}°',style:Theme.of(context).textTheme.headlineMedium),Text(weather!.description),Text('갱신 ${two(weather!.fetchedAt.hour)}:${two(weather!.fetchedAt.minute)}')],if(weatherBusy)const Text('갱신 중'),if(weatherError)const Text('갱신 실패'),if(weather==null&&!weatherBusy&&!weatherError)const Text('위치 미설정'),action('위치 설정',()async{final v=await prompt('위도,경도',saved);if(v==null)return;final p=v.split(',');if(p.length!=2)return;final a=double.tryParse(p[0]),b=double.tryParse(p[1]);if(a==null||b==null||!a.isFinite||!b.isFinite||a.abs()>90||b.abs()>180)return;await save('$a,$b');if(!mounted)return;setState(()=>weather=null);await refreshWeather();}),action('새로고침',refreshWeather),const Text('Open-Meteo',style:TextStyle(fontSize:10))]);
    case 'agenda':return AgendaPanel(prefs:widget.prefs,editing:widget.editing);
    case 'calendar':final first=DateTime(now.year,now.month,1);final count=DateTime(now.year,now.month+1,0).day;return panel('${now.year}년 ${now.month}월',[for(var row=0;row<(count+first.weekday-1+6)~/7;row++) Row(children:[for(var col=0;col<7;col++) Expanded(child:Builder(builder:(_){final day=row*7+col-first.weekday+2;return Center(child:Text(day<1||day>count?'':'$day',style:TextStyle(fontSize:12,color:day==now.day?Theme.of(context).colorScheme.primary:null,fontWeight:day==now.day?FontWeight.bold:null)));}))])]);
    case 'memo':return panel('메모',[Text(saved.isEmpty?'메모 없음':saved),action('수정',()async{final v=await prompt('메모',saved);if(v!=null)await save(v);})]);
    case 'tasks':final items=tasks;return panel('할 일 ${items.where((e)=>e['done']==true).length}/${items.length}',[for(var i=0;i<items.length;i++) Row(children:[Checkbox(value:items[i]['done']==true,onChanged:widget.editing?null:(v){items[i]['done']=v;save(jsonEncode(items));}),Expanded(child:Text('${items[i]['text']}')),IconButton(onPressed:widget.editing?null:(){items.removeAt(i);save(jsonEncode(items));},icon:const Icon(Icons.close,size:16))]),action('추가',()async{final v=await prompt('할 일','');if(v!=null&&v.trim().isNotEmpty){items.add({'text':v.trim(),'done':false});await save(jsonEncode(items));}})]);
    case 'battery':return panel('배터리',[Text(level==null?'확인 불가':'$level%',style:Theme.of(context).textTheme.headlineMedium),if(batteryState==BatteryState.charging)const Text('충전 중')]);
    case 'dday':final target=DateTime.tryParse(saved);final days=target==null?null:DateTime.utc(target.year,target.month,target.day).difference(DateTime.utc(now.year,now.month,now.day)).inDays;return panel('디데이',[Text(days==null?'목표일 미설정':days==0?'D-Day':days>0?'D-$days':'D+${-days}',style:Theme.of(context).textTheme.headlineMedium),action('목표일 설정',()async{final d=await showDatePicker(context:context,initialDate:now,firstDate:DateTime(1900),lastDate:DateTime(2100));if(d!=null)await save(d.toIso8601String());})]);
    case 'photo':return Column(children:[Expanded(child:saved.isEmpty?const Center(child:Text('사진 없음')):Image.file(File(saved),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Text('사진 없음'))),action('사진 선택',pickPhoto)]);
    default:return const SizedBox.shrink();
  }}
}
