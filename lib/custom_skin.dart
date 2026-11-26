import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'skin.dart';

class CustomSkin {
  const CustomSkin({this.accent, this.opacity=1, this.radius=8, this.scale=1, this.font='system', this.photo});
  final int? accent;
  final double opacity, radius, scale;
  final String font;
  final String? photo;
  static CustomSkin decode(String? raw) {
    try {
      final m=jsonDecode(raw!) as Map;
      double bounded(String k,double fallback,double min,double max) {final v=m[k];return v is num && v.isFinite?v.toDouble().clamp(min,max).toDouble():fallback;}
      return CustomSkin(accent:m['accent'] is int && m['accent']>=0 && m['accent']<=0xffffffff?m['accent']:null,opacity:bounded('opacity',1,0,1),radius:bounded('radius',8,0,24),scale:bounded('scale',1,.8,1.3),font:m['font']=='monospace'?'monospace':'system',photo:m['photo'] is String?m['photo']:null);
    } catch (_) {return const CustomSkin();}
  }
  String encode()=>jsonEncode({'accent':accent,'opacity':opacity,'radius':radius,'scale':scale,'font':font,'photo':photo});
  SkinStyle apply(SkinStyle base)=>SkinStyle(base.id,base.label,base.background,base.surface,base.brightness,accent:accent==null?base.accent:Color(accent!),radius:radius,cardOpacity:opacity);
}

class CustomSkinEditor extends StatefulWidget {
  const CustomSkinEditor({super.key,required this.initial});
  final CustomSkin initial;
  @override State<CustomSkinEditor> createState()=>_CustomSkinEditorState();
}
class _CustomSkinEditorState extends State<CustomSkinEditor> {
  late int? accent=widget.initial.accent;
  late double opacity=widget.initial.opacity,radius=widget.initial.radius,scale=widget.initial.scale;
  late String font=widget.initial.font;
  late String? photo=widget.initial.photo;
  bool busy=false;
  Future<void> pick() async {
    setState(()=>busy=true);
    try {final p=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1920,maxHeight:1920);if(p==null)return;final dir=await getApplicationDocumentsDirectory();final f=await File(p.path).copy('${dir.path}/skin_${DateTime.now().microsecondsSinceEpoch}');if(mounted)setState(()=>photo=f.path);}
    catch (_) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('사진 선택 실패')));}
    finally {if(mounted)setState(()=>busy=false);}
  }
  CustomSkin get current=>CustomSkin(accent:accent,opacity:opacity,radius:radius,scale:scale,font:font,photo:photo);
  @override Widget build(BuildContext context)=>SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('사용자 스킨'), const SizedBox(height:12), SkinPreview(style:current.apply(SkinStyle.resolve(Theme.of(context).brightness==Brightness.dark?'dark':'light'))),
    const Text('포인트 컬러'),Wrap(spacing:8,children:[ChoiceChip(label:const Text('기본'),selected:accent==null,onSelected:(_)=>setState(()=>accent=null)),for(final c in [0xff86a873,0xff80aaff,0xffe6ad75,0xffc4a4df,0xffaaaaaa]) ChoiceChip(label:CircleAvatar(radius:9,backgroundColor:Color(c)),selected:accent==c,onSelected:(_)=>setState(()=>accent=c))]),
    Text('카드 불투명도 ${(opacity*100).round()}%'),Slider(value:opacity,onChanged:(v)=>setState(()=>opacity=v)),
    Text('모서리 ${radius.round()} dp'),Slider(value:radius,max:24,onChanged:(v)=>setState(()=>radius=v)),
    Text('글자 크기 ${(scale*100).round()}%'),Slider(value:scale,min:.8,max:1.3,onChanged:(v)=>setState(()=>scale=v)),
    DropdownButton<String>(value:font,items:const [DropdownMenuItem(value:'system',child:Text('시스템 글꼴')),DropdownMenuItem(value:'monospace',child:Text('고정폭 글꼴'))],onChanged:(v){if(v!=null)setState(()=>font=v);}),
    ListTile(title:Text(photo==null?'배경 사진 선택':'배경 사진 변경'),onTap:busy?null:pick,trailing:photo==null?null:IconButton(onPressed:busy?null:()=>setState(()=>photo=null),icon:const Icon(Icons.close))),
    Row(children:[TextButton(onPressed:busy?null:()=>setState((){accent=null;opacity=1;radius=8;scale=1;font='system';photo=null;}),child:const Text('초기화')),const Spacer(),FilledButton(onPressed:busy?null:()=>Navigator.pop(context,current),child:const Text('저장'))])
  ])));
}
