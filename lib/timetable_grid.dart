import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Timetable {
  String id; String day, period, cls, stream, subject, teacher, time; bool isBreak;
  String? group; // NEW: e.g Group A, Science Group, etc
  Timetable({required this.id, required this.day, required this.period, required this.cls, required this.stream, required this.subject, required this.teacher, required this.time, this.isBreak=false, this.group});
  Map<String,dynamic> toMap()=>{'id':id,'day':day,'period':period,'cls':cls,'stream':stream,'subject':subject,'teacher':teacher,'time':time,'isBreak':isBreak, 'group':group??''};
  static Timetable fromMap(Map m)=>Timetable(id:m['id'],day:m['day'],period:m['period'],cls:m['cls'],stream:m['stream'],subject:m['subject'],teacher:m['teacher'],time:m['time'],isBreak:m['isBreak']??false, group:m['group']);
}

class PeriodConfig {
  String p; String t;
  PeriodConfig({required this.p, required this.t});
  Map<String,dynamic> toMap()=> {'p':p,'t':t};
  static PeriodConfig fromMap(Map m)=> PeriodConfig(p:m['p']??'P1', t:m['t']??'08:00-08:40');
}

class TimetableGridPage extends StatefulWidget {
  final FirebaseFirestore db;
  final dynamic curUser;
  const TimetableGridPage({super.key, required this.db, required this.curUser});
  @override State<TimetableGridPage> createState()=> _TimetableGridPageState();
}

class _TimetableGridPageState extends State<TimetableGridPage> {
  // ===== PERMISSION: ONLY HT, Deputy HT, DOS, Admin CAN EDIT =====
  bool get canEdit {
    String r = widget.curUser.role.toLowerCase().trim();
    return r.contains('admin') ||
           r.contains('director') ||
           r.contains('dos') ||
           r.contains('deputy') ||
           r == 'ht' ||
           r.contains('head teacher') ||
           r.contains('headteacher');
  }

  String selectedClass='S.1'; String selectedStream='Blue';
  List<String> classes=['S.1','S.2','S.3','S.4','S.5','S.6'];
  List<String> streamsS14=['Blue','Red','Green','White'];
  List<String> streamsS56=['Sciences','Arts'];
  List<String> get currentStreams=> (selectedClass=='S.5'||selectedClass=='S.6')? streamsS56 : streamsS14;
  List<String> days=['Monday','Tuesday','Wednesday','Thursday','Friday'];

  List<PeriodConfig> s14Periods=[ PeriodConfig(p:'P1',t:'08:00-08:35'), PeriodConfig(p:'P2',t:'08:35-09:10'), PeriodConfig(p:'P3',t:'09:10-09:45'), PeriodConfig(p:'Break',t:'09:45-10:15'), PeriodConfig(p:'P4',t:'10:15-10:50'), PeriodConfig(p:'P5',t:'10:50-11:25'), PeriodConfig(p:'P6',t:'11:25-12:00'), PeriodConfig(p:'Lunch',t:'12:00-14:00'), PeriodConfig(p:'P7',t:'14:00-14:35'), PeriodConfig(p:'P8',t:'14:35-15:10'), ];
  List<PeriodConfig> s56Periods=[ PeriodConfig(p:'P1',t:'08:00-09:20'), PeriodConfig(p:'P2',t:'09:20-10:40'), PeriodConfig(p:'Break',t:'10:40-11:10'), PeriodConfig(p:'P3',t:'11:10-12:30'), PeriodConfig(p:'Lunch',t:'12:30-14:00'), PeriodConfig(p:'P4',t:'14:00-15:20'), PeriodConfig(p:'P5',t:'15:20-16:40'), ];
  List<PeriodConfig> get currentPeriods=> (selectedClass=='S.5'||selectedClass=='S.6')? s56Periods : s14Periods;

  List<String> subjects=['MATH','ENG','PHY','CHEM','BIO','HIST','GEO','CRE','IRE','COMMERCE','ENT','AGRIC','ART','LUGANDA','KISWAHILI','ICT','BREAK','LUNCH','FREE','GENERAL PAPER','SUB-MATH'];
  List<String> teachersList=[];
  Map<String, List<Timetable>> gridData={}; // KEY CHANGE: List
  bool loading=false; bool saving=false;

  @override void initState(){ super.initState(); _loadConfig(); _loadTeachers(); _loadTimetable(); }

  Future<void> _loadConfig() async {
    try{
      var doc=await widget.db.collection('app_settings').doc('timetable_config').get();
      if(doc.exists){
        var d=doc.data()!;
        if(d['s14']!=null){ s14Periods=(d['s14'] as List).map((e)=> PeriodConfig.fromMap(e)).toList(); }
        if(d['s56']!=null){ s56Periods=(d['s56'] as List).map((e)=> PeriodConfig.fromMap(e)).toList(); }
      }
      var subDoc=await widget.db.collection('app_settings').doc('custom_subjects').get();
      if(subDoc.exists && subDoc.data()!['subjects']!=null){
        var loaded = List<String>.from(subDoc.data()!['subjects']);
        for(var s in loaded){ if(!subjects.contains(s)) subjects.add(s); }
      }
      setState((){});
    }catch(_){}
  }
  Future<void> _saveConfig() async {
    if(!canEdit){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔒 Only Admin/DOS/Deputy HT/HT can customize periods'), backgroundColor: Colors.orange));
      return;
    }
    await widget.db.collection('app_settings').doc('timetable_config').set({
      's14': s14Periods.map((e)=> e.toMap()).toList(),
      's56': s56Periods.map((e)=> e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Period config saved'), backgroundColor: Colors.green));
  }
  Future<void> _loadTeachers() async {
    try{
      var snap=await widget.db.collection('teacher_profiles').get();
      if(snap.docs.isEmpty) snap=await widget.db.collection('accounts').get();
      setState(()=> teachersList=snap.docs.map((d)=>(d.data()['name']??d.id).toString()).toList());
    }catch(_){}
  }
  Future<void> _loadTimetable() async {
    setState(()=> loading=true);
    var snap=await widget.db.collection('timetable').where('cls',isEqualTo:selectedClass).where('stream',isEqualTo:selectedStream).get();
    Map<String, List<Timetable>> map={};
    for(var d in snap.docs){
      var t=Timetable.fromMap(d.data());
      String key='${t.day}|${t.period}';
      map.putIfAbsent(key, ()=> []).add(t);
    }
    setState(()=> {gridData=map, loading=false});
  }

  void _openPeriodSettings(){
    if(!canEdit){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔒 Only Admin/DOS/Deputy HT/HT can edit periods'), backgroundColor: Colors.orange));
      return;
    }
    bool isS56=(selectedClass=='S.5'||selectedClass=='S.6');
    List<PeriodConfig> editing=isS56? List.from(s56Periods) : List.from(s14Periods);
    showDialog(context: context, builder: (ctx)=> StatefulBuilder(builder: (ctx2,setS){
      return AlertDialog(
        title: Text('Customize Periods - ${isS56?'S.5-S.6':'S.1-S.4'}', style: TextStyle(fontSize:13, fontWeight: FontWeight.bold)),
        content: SizedBox(width: 400, height: 400, child: Column(children: [
          Expanded(child: ListView.builder(itemCount: editing.length, itemBuilder: (c,i){
            return Row(children: [
              Expanded(flex:2, child: TextField(controller: TextEditingController(text: editing[i].p), decoration: InputDecoration(labelText: 'Period', isDense:true, border: OutlineInputBorder()), style: TextStyle(fontSize:12), onChanged: (v)=> editing[i].p=v)),
              SizedBox(width:6),
              Expanded(flex:3, child: TextField(controller: TextEditingController(text: editing[i].t), decoration: InputDecoration(labelText: 'Time', isDense:true, border: OutlineInputBorder()), style: TextStyle(fontSize:12), onChanged: (v)=> editing[i].t=v)),
              IconButton(icon: Icon(Icons.delete, color: Colors.red, size:18), onPressed: ()=> setS(()=> editing.removeAt(i))),
            ]);
          })),
          Row(children: [
            ElevatedButton.icon(icon: Icon(Icons.add, size:16), label: Text('Add Period', style: TextStyle(fontSize:11)), onPressed: ()=> setS(()=> editing.add(PeriodConfig(p:'P${editing.length+1}',t:'15:20-16:00')))),
            SizedBox(width:8),
            ElevatedButton.icon(icon: Icon(Icons.add, size:16), label: Text('Add Break', style: TextStyle(fontSize:11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: ()=> setS(()=> editing.add(PeriodConfig(p:'Break',t:'10:00-10:30')))),
          ])
        ])),
        actions: [ TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white), onPressed: (){ setState(()=> isS56? s56Periods=editing : s14Periods=editing); Navigator.pop(ctx); _saveConfig(); }, child: Text('SAVE')), ],
      );
    }));
  }

  // NEW MULTI EDIT
  void _editCell(String day, PeriodConfig per){
    if(!canEdit){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔒 View only - Only Admin/DOS/D.HT/HT can edit'), backgroundColor: Colors.orange));
      return;
    }
    String key='$day|${per.p}';
    List<Timetable> existingList = gridData[key]??[];
    // FIX: tempList OUTSIDE builder so setS doesn't reset it
    List<Timetable> tempList = List.from(existingList);

    showDialog(context: context, builder: (ctx)=> StatefulBuilder(builder: (ctx2,setS){
      return AlertDialog(
        title: Text('$day ${per.p} (${per.t}) - $selectedClass $selectedStream\n${tempList.length} subject(s) in this period', style: TextStyle(fontSize:12, fontWeight: FontWeight.bold)),
        content: SizedBox(width: 450, height: 450, child: Column(children: [
          if(tempList.isEmpty) Padding(padding: EdgeInsets.all(12), child: Text('No subject yet. Add one below.', style: TextStyle(fontSize:11, color: Colors.grey))),
          Expanded(child: ListView.builder(itemCount: tempList.length, itemBuilder: (c,i){
            var t=tempList[i];
            return Card(color: t.isBreak? Colors.orange.shade50 : Colors.blue.shade50, child: ListTile(
              dense:true,
              title: Text('${t.subject} - ${t.teacher}', style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)),
              subtitle: Text('Group: ${t.group??'All'} | ${t.time}', style: TextStyle(fontSize:9)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: Icon(Icons.edit, size:16, color: Colors.blue), onPressed: ()=> _editSingleSubject(day, per, t, (updated){
                  setS(()=> tempList[i]=updated);
                })),
                IconButton(icon: Icon(Icons.delete, size:16, color: Colors.red), onPressed: ()=> setS(()=> tempList.removeAt(i))),
              ]),
            ));
          })),
          Divider(),
          Text('Add New Subject in Same Period:', style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)),
          SizedBox(height:6),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add Subject + Teacher to this Period'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: (){
              _addSingleSubject(day, per, (newT){
                setS(()=> tempList.add(newT));
              });
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: (){
              setState(()=> gridData.remove(key));
              widget.db.collection('timetable').where('cls',isEqualTo:selectedClass).where('stream',isEqualTo:selectedStream).where('day',isEqualTo:day).where('period',isEqualTo:per.p).get().then((snap){ for(var d in snap.docs) d.reference.delete(); });
              Navigator.pop(ctx);
              setState((){});
            },
            child: Text('Clear All in Cell')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white),
            onPressed: () async {
              setState(()=> gridData[key]=tempList);
              Navigator.pop(ctx);
              if(tempList.isNotEmpty){
                try{
                  var batch=widget.db.batch();
                  var oldSnap=await widget.db.collection('timetable').where('cls',isEqualTo:selectedClass).where('stream',isEqualTo:selectedStream).where('day',isEqualTo:day).where('period',isEqualTo:per.p).get();
                  for(var d in oldSnap.docs) batch.delete(d.reference);
                  for(var t in tempList) batch.set(widget.db.collection('timetable').doc(t.id), t.toMap());
                  await batch.commit();
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Saved ${tempList.length} to Firebase for $day ${per.p}'), backgroundColor: Colors.green));
                }catch(e){
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Auto-save failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: Text('Save Cell (${tempList.length})')
          ),
        ],
      );
    }));
  }

  void _addSingleSubject(String day, PeriodConfig per, Function(Timetable) onAdd){
    String selSubject='MATH'; String selTeacher=''; String group=''; bool isBreak=(per.p=='Break'||per.p=='Lunch');
    TextEditingController customCtrl=TextEditingController();
    bool showCustom=false;
    showDialog(context: context, builder: (ctx2)=> StatefulBuilder(builder: (c,setS){
      return AlertDialog(
        title: Text('Add to $day ${per.p}', style: TextStyle(fontSize:12, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: subjects.contains(selSubject)? selSubject:null,
            decoration: InputDecoration(labelText:'Subject', border: OutlineInputBorder(), isDense:true),
            items: [...subjects.map((s)=> DropdownMenuItem(value:s, child: Text(s, style: TextStyle(fontSize:12)))).toList(), DropdownMenuItem(value: '__ADD_NEW__', child: Text('➕ ADD NEW SUBJECT...', style: TextStyle(fontSize:12, color: Colors.green, fontWeight: FontWeight.bold)))],
            onChanged: (v){ if(v=='__ADD_NEW__') setS(()=> showCustom=true); else setS(()=> selSubject=v!); },
          ),
          if(showCustom)...[
            SizedBox(height:6),
            TextField(controller: customCtrl, decoration: InputDecoration(labelText:'New Subject', border: OutlineInputBorder(), isDense:true, suffixIcon: IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: (){ String ns=customCtrl.text.trim().toUpperCase(); if(ns.isNotEmpty){ if(!subjects.contains(ns)){ setState(()=> subjects.add(ns)); widget.db.collection('app_settings').doc('custom_subjects').set({'subjects':subjects}, SetOptions(merge:true)); } setS(()=> selSubject=ns); setS(()=> showCustom=false); } }))),
          ],
          SizedBox(height:8),
          DropdownButtonFormField<String>(value: teachersList.contains(selTeacher)? selTeacher:null, decoration: InputDecoration(labelText:'Teacher', border: OutlineInputBorder(), isDense:true), items: [DropdownMenuItem(value:'', child: Text('Free')),...teachersList.map((t)=> DropdownMenuItem(value:t, child: Text(t, style: TextStyle(fontSize:11)))).toList()], onChanged: (v)=> setS(()=> selTeacher=v??'')),
          SizedBox(height:8),
          TextField(decoration: InputDecoration(labelText:'Group / Option e.g Group A, Commerce Group (optional)', border: OutlineInputBorder(), isDense:true), style: TextStyle(fontSize:11), onChanged: (v)=> group=v),
          CheckboxListTile(dense:true, title: Text('Is Break?', style: TextStyle(fontSize:11)), value: isBreak, onChanged: (v)=> setS(()=> isBreak=v!)),
        ])),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(onPressed: (){
            String id='TT_${selectedClass}_${selectedStream}_${day}_${per.p}_${selSubject}_${DateTime.now().millisecondsSinceEpoch}'.replaceAll(' ', '_');
            var t=Timetable(id:id, day:day, period:per.p, cls:selectedClass, stream:selectedStream, subject: showCustom && customCtrl.text.trim().isNotEmpty? customCtrl.text.trim().toUpperCase() : selSubject, teacher:selTeacher, time:per.t, isBreak:isBreak, group:group);
            onAdd(t);
            Navigator.pop(c);
          }, child: Text('Add')),
        ],
      );
    }));
  }

  void _editSingleSubject(String day, PeriodConfig per, Timetable existing, Function(Timetable) onUpdate){
    String selSubject=existing.subject; String selTeacher=existing.teacher; String group=existing.group??''; bool isBreak=existing.isBreak;
    showDialog(context: context, builder: (ctx2)=> StatefulBuilder(builder: (c,setS){
      return AlertDialog(
        title: Text('Edit ${existing.subject}', style: TextStyle(fontSize:12)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: subjects.contains(selSubject)? selSubject:null, decoration: InputDecoration(labelText:'Subject', border: OutlineInputBorder(), isDense:true), items: subjects.map((s)=> DropdownMenuItem(value:s, child: Text(s, style: TextStyle(fontSize:12)))).toList(), onChanged: (v)=> setS(()=> selSubject=v!)),
          SizedBox(height:8),
          DropdownButtonFormField<String>(value: teachersList.contains(selTeacher)? selTeacher:null, decoration: InputDecoration(labelText:'Teacher', border: OutlineInputBorder(), isDense:true), items: [DropdownMenuItem(value:'', child: Text('Free')),...teachersList.map((t)=> DropdownMenuItem(value:t, child: Text(t, style: TextStyle(fontSize:11)))).toList()], onChanged: (v)=> setS(()=> selTeacher=v??'')),
          SizedBox(height:8),
          TextField(controller: TextEditingController(text: group), decoration: InputDecoration(labelText:'Group', border: OutlineInputBorder(), isDense:true), style: TextStyle(fontSize:11), onChanged: (v)=> group=v),
        ])),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(onPressed: (){
            var updated=Timetable(id:existing.id, day:day, period:per.p, cls:selectedClass, stream:selectedStream, subject:selSubject, teacher:selTeacher, time:per.t, isBreak:isBreak, group:group);
            onUpdate(updated);
            Navigator.pop(c);
          }, child: Text('Update')),
        ],
      );
    }));
  }

  Future<void> _saveAll() async {
    if(!canEdit){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔒 Only Admin/DOS/Deputy HT/HT can save - your role: ${widget.curUser.role}'), backgroundColor: Colors.orange));
      return;
    }
    if(gridData.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grid empty - add at least 1 period'), backgroundColor: Colors.orange));
      return;
    }
    setState(()=> saving=true);
    try{
      var batch=widget.db.batch(); int count=0; int total=0;
      for(var list in gridData.values){
        for(var t in list){
          batch.set(widget.db.collection('timetable').doc(t.id), t.toMap());
          total++; count++;
          if(count>=400){ await batch.commit(); batch=widget.db.batch(); count=0; }
        }
      }
      if(count>0) await batch.commit();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Saved $total lessons for $selectedClass $selectedStream'), backgroundColor: Colors.green));
    }catch(e){
      print('SAVE ERROR $e');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Save failed: $e'), backgroundColor: Colors.red, duration: Duration(seconds:5)));
    }
    setState(()=> saving=false);
  }

  Widget _buildCell(String day, PeriodConfig per){
    String key='$day|${per.p}'; var dataList=gridData[key]; bool isBreakCell=per.p=='Break'||per.p=='Lunch';
    if(dataList!=null && dataList.isNotEmpty) isBreakCell = dataList.first.isBreak;
    return InkWell(
      onTap: (){
        if(!canEdit){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔒 View only - Only Admin/DOS/D.HT/HT can edit'), backgroundColor: Colors.orange)); return; }
        _editCell(day, per);
      },
      child: Container(
        width: 120,
        height: dataList==null? 60 : (60 + (dataList.length-1)*28).toDouble(),
        margin: EdgeInsets.all(2), padding: EdgeInsets.all(4),
        decoration: BoxDecoration(color: isBreakCell? Colors.orange.shade100 : (dataList==null? Colors.grey.shade100 : Colors.blue.shade50), border: Border.all(color: dataList==null? Colors.grey.shade300 : Colors.blue.shade300, width: dataList==null?0.5:1.2), borderRadius: BorderRadius.circular(6)),
        child: dataList==null || dataList.isEmpty
         ? Center(child: Text('+ Add', style: TextStyle(fontSize:9, color: Colors.grey)))
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if(dataList.length>1) Container(padding: EdgeInsets.symmetric(horizontal:4, vertical:1), decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(10)), child: Text('x${dataList.length}', style: TextStyle(fontSize:8, color: Colors.white, fontWeight: FontWeight.bold))),
             ...dataList.map((d)=> Container(margin: EdgeInsets.only(top:2), padding: EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)), child: Column(children: [
                Text(d.subject, style: TextStyle(fontSize:9, fontWeight: FontWeight.bold, color: isBreakCell? Colors.orange.shade900 : Colors.indigo), textAlign: TextAlign.center, maxLines:1, overflow: TextOverflow.ellipsis),
                Text(d.teacher.isEmpty? 'Free' : d.teacher.split(' ').first, style: TextStyle(fontSize:7, color: Colors.black87), maxLines:1, overflow: TextOverflow.ellipsis),
                if(d.group!=null && d.group!.isNotEmpty) Text(d.group!, style: TextStyle(fontSize:6, color: Colors.green.shade700, fontStyle: FontStyle.italic)),
              ]))).toList(),
            ]),
      ),
    );
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Grid ${canEdit? 'EDIT' : 'VIEW ONLY'} - $selectedClass $selectedStream (${gridData.values.fold(0,(a,b)=>a+b.length)})', style: TextStyle(fontSize:12)), backgroundColor: canEdit? Color(0xFF0D47A1) : Colors.grey.shade700, foregroundColor: Colors.white, actions: [if(!canEdit) Padding(padding: EdgeInsets.only(top:12, right:6), child: Text('VIEW ONLY', style: TextStyle(fontSize:10, color: Colors.white, fontWeight: FontWeight.bold))), if(canEdit) IconButton(icon: Icon(Icons.settings), onPressed: _openPeriodSettings), IconButton(onPressed: _loadTimetable, icon: Icon(Icons.refresh))]),
      floatingActionButton: canEdit? FloatingActionButton.extended(onPressed: saving?null:_saveAll, backgroundColor: Colors.green, icon: saving? SizedBox(width:16,height:16,child:CircularProgressIndicator(color: Colors.white, strokeWidth:2)): Icon(Icons.save), label: Text(saving? 'Saving...' : 'SAVE ${gridData.values.fold(0,(a,b)=>a+b.length)}')) : null,
      body: Column(children: [
        Card(margin: EdgeInsets.all(8), child: Padding(padding: EdgeInsets.all(8), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: selectedClass, decoration: InputDecoration(labelText:'Class', border: OutlineInputBorder(), isDense:true), items: classes.map((c)=> DropdownMenuItem(value:c, child: Text(c, style: TextStyle(fontSize:12)))).toList(), onChanged: (v){ setState(()=> selectedClass=v!); _loadTimetable(); })),
          SizedBox(width:8),
          Expanded(child: DropdownButtonFormField<String>(value: currentStreams.contains(selectedStream)? selectedStream : currentStreams.first, decoration: InputDecoration(labelText:'Stream', border: OutlineInputBorder(), isDense:true), items: currentStreams.map((s)=> DropdownMenuItem(value:s, child: Text(s, style: TextStyle(fontSize:12)))).toList(), onChanged: (v){ setState(()=> selectedStream=v!); _loadTimetable(); })),
          SizedBox(width:8),
          ElevatedButton.icon(icon: Icon(Icons.tune, size:16), label: Text('Edit Time', style: TextStyle(fontSize:10)), onPressed: _openPeriodSettings),
        ]))),
        if(loading) LinearProgressIndicator(),
        Container(padding: EdgeInsets.all(4), color: Colors.blue.shade50, child: Row(children: [Icon(Icons.info, size:12), SizedBox(width:4), Expanded(child: Text('MULTI: Tap cell to add 2-3 subjects in same period (e.g AGRIC + COMMERCE same time).', style: TextStyle(fontSize:9))), Text('${gridData.values.fold(0,(a,b)=>a+b.length)} lessons', style: TextStyle(fontSize:9, fontWeight: FontWeight.bold))])),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(scrollDirection: Axis.vertical, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width:70,height:40,margin: EdgeInsets.all(2), alignment: Alignment.center, decoration: BoxDecoration(color: Color(0xFF0D47A1), borderRadius: BorderRadius.circular(6)), child: Text('DAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:11))),...currentPeriods.map((per)=> Container(width:120,height:40,margin: EdgeInsets.all(2), alignment: Alignment.center, decoration: BoxDecoration(color: per.p=='Break'||per.p=='Lunch'? Colors.orange.shade700 : Colors.indigo.shade700, borderRadius: BorderRadius.circular(6)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(per.p, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:10)), Text(per.t, style: TextStyle(color: Colors.white70, fontSize:7))]))).toList()]),
         ...days.map((day)=> Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width:70,height:60,margin: EdgeInsets.all(2), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text(day.substring(0,3).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize:11))),...currentPeriods.map((per)=> _buildCell(day, per)).toList()])).toList(),
        ])))),
      ]),
    );
  }
}