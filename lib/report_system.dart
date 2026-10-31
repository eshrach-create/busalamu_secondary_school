import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;
import 'timetable_model.dart';

// ========== UNEB OFFICIAL 2024-2026 CBC ==========
class UNEBGrading {
  static Map<String, dynamic> oLevelNew(double m) {
    if (m >= 80) return {'grade': 'A', 'desc': 'Exceptional'};
    if (m >= 70) return {'grade': 'B', 'desc': 'Outstanding'};
    if (m >= 60) return {'grade': 'C', 'desc': 'Satisfactory'};
    if (m >= 50) return {'grade': 'D', 'desc': 'Basic'};
    if (m >= 40) return {'grade': 'E', 'desc': 'Elementary'};
    return {'grade': 'O', 'desc': 'Below Basic'};
  }
  static Map<String, dynamic> oLevelOld(double m) {
    if (m >= 80) return {'grade': 'D1'};
    if (m >= 70) return {'grade': 'D2'};
    if (m >= 65) return {'grade': 'C3'};
    if (m >= 60) return {'grade': 'C4'};
    if (m >= 55) return {'grade': 'C5'};
    if (m >= 50) return {'grade': 'C6'};
    if (m >= 45) return {'grade': 'P7'};
    if (m >= 35) return {'grade': 'P8'};
    return {'grade': 'F'};
  }
  static Map<String, dynamic> aLevel(double m) {
    if (m >= 80) return {'grade': 'A', 'point': 6, 'desc': 'Principal'};
    if (m >= 70) return {'grade': 'B', 'point': 5, 'desc': 'Principal'};
    if (m >= 65) return {'grade': 'C', 'point': 4, 'desc': 'Principal'};
    if (m >= 60) return {'grade': 'D', 'point': 3, 'desc': 'Principal'};
    if (m >= 55) return {'grade': 'E', 'point': 2, 'desc': 'Principal'};
    if (m >= 45) return {'grade': 'O', 'point': 1, 'desc': 'Subsidiary'};
    return {'grade': 'F', 'point': 0, 'desc': 'Fail'};
  }
  static String gradeOnly(String system, double m) {
    if (system == "A Level") return aLevel(m)['grade'];
    if (system == "New Curriculum") return oLevelNew(m)['grade'];
    return oLevelOld(m)['grade'];
  }
}

// ========== ENTRY - KEEP SAME NAME AS YOUR MAIN.DART ==========
class ReportSystemHome extends StatelessWidget {
  final dynamic curUser;
  const ReportSystemHome({super.key, this.curUser});

  bool get isHT {
    if (curUser == null) return true;
    String r = (curUser.role?? '').toString().toLowerCase();
    return r.contains('ht') || r.contains('admin') || r.contains('dos') || r.contains('deputy') || r.contains('director');
  }
  @override Widget build(BuildContext context) => isHT? HTClassOverallPage(curUser: curUser) : TeacherHome(curUser: curUser);
}

// ========== TEACHER HOME - ISOLATED ==========
class TeacherHome extends StatefulWidget {
  final dynamic curUser;
  const TeacherHome({super.key, this.curUser});
  @override State<TeacherHome> createState() => _TeacherHomeState();
}
class _TeacherHomeState extends State<TeacherHome> {
  List<Timetable> myTT = [];
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    String name = widget.curUser?.name?? '';
    var snap = await FirebaseFirestore.instance.collection('timetable').where('teacher', isEqualTo: name).get();
    setState(() { myTT = snap.docs.map((d) => Timetable.fromMap(d.data())).toList(); loading = false; });
  }
  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    var subjects = myTT.map((e) => e.subject).toSet().toList()..sort();
    var classes = myTT.map((e) => "${e.cls} ${e.stream}").toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text("My Marks - ${widget.curUser?.name}"), backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white),
      body: ListView(padding: EdgeInsets.all(12), children: [
        Card(color: Colors.green.shade50, child: ListTile(leading: Icon(Icons.lock, color: Colors.green), title: Text("SECURED: You see ONLY your subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text("${myTT.length} periods | Subjects: ${subjects.join(', ')}"))),
       ...classes.map((cs) {
          var p = cs.split(' '); String cls = p[0]; String stream = p.sublist(1).join(' ');
          var ttFor = myTT.where((e) => e.cls == cls && e.stream == stream).toList();
          return Card(child: ListTile(title: Text(cs, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(ttFor.map((e) => e.subject).join(', ')), trailing: Icon(Icons.edit), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EnterMarksPage(teacher: {'id': widget.curUser?.name?? '', 'name': widget.curUser?.name?? '', 'initials': ''}, subject: ttFor.first.subject, cls: cls, stream: stream, term: "Term I 2026", exam: "MID", grading: (cls=="S.5"||cls=="S.6")? "A Level" : "New Curriculum", myTimetable: ttFor, curUser: widget.curUser)))));
        }),
        if (myTT.isEmpty) Padding(padding: EdgeInsets.all(30), child: Text("No timetable assigned. Ask DOS to add you in Timetable Grid with your exact name: ${widget.curUser?.name}", textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
      ]),
    );
  }
}

class SubjectClassSelectPage extends StatelessWidget {
  final Map<String, dynamic> teacher; final List<Timetable> myTimetable; final dynamic curUser;
  const SubjectClassSelectPage({super.key, required this.teacher, required this.myTimetable, this.curUser});
  @override Widget build(BuildContext c) => TeacherHome(curUser: curUser);
}

// ========== ENTER MARKS - TEACHER ONLY HIS MARKS ==========
class EnterMarksPage extends StatefulWidget {
  final Map<String,dynamic> teacher; final String subject, cls, stream, term, exam, grading; final String? group; final List<Timetable> myTimetable; final dynamic curUser;
  const EnterMarksPage({super.key, required this.teacher, required this.subject, required this.cls, required this.stream, required this.term, required this.exam, required this.grading, this.group, this.myTimetable = const [], this.curUser});
  @override State<EnterMarksPage> createState()=> _EnterMarksPageState();
}
class _EnterMarksPageState extends State<EnterMarksPage> {
  List<Map<String,dynamic>> students=[]; Map<String, TextEditingController> ctrls={}; bool loading=true, saving=false;
  String? selSubject; String? selTerm; String? selExam;
  @override void initState(){ selSubject=widget.subject; selTerm=widget.term; selExam=widget.exam; super.initState(); _load(); }
  Future<void> _load() async {
    var snap = await FirebaseFirestore.instance.collection('students').where('cls', isEqualTo: widget.cls).where('stream', isEqualTo: widget.stream).get();
    var list = snap.docs.map((d)=> d.data()).toList();
    for(var s in list){
      String sid = s['idNo']??''; String docId = "${selTerm}_${selExam}_${widget.cls}_${widget.stream}_${selSubject}_$sid".replaceAll(' ', '_');
      var mDoc = await FirebaseFirestore.instance.collection('marks').doc(docId).get();
      ctrls[sid]= TextEditingController(text: mDoc.exists? mDoc.data()!['mark'].toString():'');
    }
    setState((){ students=list; loading=false; });
  }
  Future<void> _save() async {
    setState(()=> saving=true);
    var batch = FirebaseFirestore.instance.batch();
    for(var s in students){
      String sid = s['idNo']??''; if(ctrls[sid]!.text.trim().isEmpty) continue;
      double mark = double.tryParse(ctrls[sid]!.text.trim())??0;
      String docId = "${selTerm}_${selExam}_${widget.cls}_${widget.stream}_${selSubject}_$sid".replaceAll(' ', '_');
      batch.set(FirebaseFirestore.instance.collection('marks').doc(docId), {
        'studentId': sid, 'studentName': s['name'], 'cls': widget.cls, 'stream': widget.stream, 'subject': selSubject, 'term': selTerm, 'exam': selExam, 'mark': mark, 'grading': widget.grading, 'grade': UNEBGrading.gradeOnly(widget.grading, mark),
        'teacherId': widget.teacher['id'], 'teacherName': widget.teacher['name'], 'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge:true));
    }
    await batch.commit(); setState(()=> saving=false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved ${selSubject}"), backgroundColor: Colors.green));
  }
  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: Text("${widget.cls} ${widget.stream} ${selSubject}"), backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white, actions: [IconButton(onPressed: _save, icon: Icon(Icons.save))]),
      body: loading? Center(child: CircularProgressIndicator()):
      Column(children: [
        Padding(padding: EdgeInsets.all(8), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: selTerm, decoration: InputDecoration(labelText: "Term", border: OutlineInputBorder(), isDense:true), items: ["Term I 2026","Term II 2026","Term III 2026"].map((e)=> DropdownMenuItem(value:e, child: Text(e, style: TextStyle(fontSize:11)))).toList(), onChanged: (v){ setState(()=> selTerm=v); _load(); })),
          SizedBox(width:6),
          Expanded(child: DropdownButtonFormField<String>(value: selExam, decoration: InputDecoration(labelText: "Exam", border: OutlineInputBorder(), isDense:true), items: ["BOT","MID","EOT"].map((e)=> DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v){ setState(()=> selExam=v); _load(); })),
        ])),
        Container(color: Colors.indigo.shade50, padding: EdgeInsets.all(8), child: Text("${selTerm} ${selExam} | ${widget.grading} | ONLY ${selSubject} - Teacher isolated", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: students.length, itemBuilder: (c,i){
          var s=students[i]; String sid=s['idNo']??'';
          String g = ctrls[sid]!.text.isNotEmpty? UNEBGrading.gradeOnly(widget.grading, double.tryParse(ctrls[sid]!.text)??0) : '-';
          return ListTile(dense:true, leading: CircleAvatar(radius:14, child: Text("${i+1}", style: TextStyle(fontSize:10))), title: Text(s['name']??'', style: TextStyle(fontSize:13, fontWeight: FontWeight.bold)), subtitle: Text("$sid | $g", style: TextStyle(fontSize:10)), trailing: SizedBox(width:80, child: TextField(controller: ctrls[sid], keyboardType: TextInputType.number, onChanged: (_)=>setState((){}), decoration: InputDecoration(labelText:"Mark", border: OutlineInputBorder(), isDense:true))));
        })),
        Padding(padding: EdgeInsets.all(10), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: saving?null:_save, child: Text(saving?"Saving...":"SAVE ${selSubject}")))),
      ]),
    );
  }
}

// ========== HT DASHBOARD - FIXED STREAMS + MISSING ==========
class HTClassOverallPage extends StatefulWidget {
  final dynamic curUser;
  const HTClassOverallPage({super.key, this.curUser});
  @override State<HTClassOverallPage> createState()=> _HTClassOverallPageState();
}
class _HTClassOverallPageState extends State<HTClassOverallPage> {
  String? selClass, selStream, selTerm="Term I 2026", selExam="MID";
  List<String> classes=["S.1","S.2","S.3","S.4","S.5","S.6"];
  List<String> streams=[];
  List<Map<String,dynamic>> students=[]; List<Map<String,dynamic>> allMarks=[]; List<Timetable> tt=[];
  bool loading=false, loadingStreams=false;

  String get grading => (selClass=='S.5'||selClass=='S.6')? "A Level" : "New Curriculum";
  bool get isALevel => selClass=='S.5'||selClass=='S.6';

  Future<void> loadStreams(String cls) async {
    setState((){ loadingStreams=true; streams=[]; selStream=null; });
    Set<String> set={};
    try{
      var s1=await FirebaseFirestore.instance.collection('students').where('cls', isEqualTo: cls).get();
      for(var d in s1.docs){ var st=d.data()['stream']; if(st!=null && st.toString().trim().isNotEmpty) set.add(st.toString().trim()); }
      var s2=await FirebaseFirestore.instance.collection('timetable').where('cls', isEqualTo: cls).get();
      for(var d in s2.docs){ var st=d.data()['stream']; if(st!=null && st.toString().trim().isNotEmpty) set.add(st.toString().trim()); }
    }catch(e){}
    if(set.isEmpty){ set = isALevel? {"Sciences","Arts","BCM","MEG","BAG","Science","Arts A"} : {"Blue","Red","Green","Yellow","West","East"}; }
    setState((){ streams=set.toList()..sort(); loadingStreams=false; });
  }

  Future<void> loadData() async {
    if(selClass==null||selStream==null) return;
    setState(()=> loading=true);
    var stu=await FirebaseFirestore.instance.collection('students').where('cls', isEqualTo: selClass).where('stream', isEqualTo: selStream).get();
    var marks=await FirebaseFirestore.instance.collection('marks').where('cls', isEqualTo: selClass).where('stream', isEqualTo: selStream).where('term', isEqualTo: selTerm).where('exam', isEqualTo: selExam).get();
    var ttable=await FirebaseFirestore.instance.collection('timetable').where('cls', isEqualTo: selClass).where('stream', isEqualTo: selStream).get();
    setState((){ students=stu.docs.map((d)=> d.data()).toList(); allMarks=marks.docs.map((d)=> d.data()).toList(); tt=ttable.docs.map((d)=> Timetable.fromMap(d.data())).toList(); loading=false; });
  }

  List<String> get expectedSubs {
    if(tt.isNotEmpty) return tt.map((e)=> e.subject).toSet().toList()..sort();
    if(allMarks.isNotEmpty) return allMarks.map((e)=> e['subject'].toString()).toSet().toList()..sort();
    return isALevel? ["MATH","ENT","ECON","GEO","HIST","PHY","CHEM","BIO","LIT","GP"] : ["MATH","ENG","PHY","CHEM","BIO","HIST","GEO","CRE","COMMERCE"];
  }

  Future<void> printMerged(String sid, String sname) async {
    var sMarks=allMarks.where((e)=> e['studentId']==sid).toList();
    double avg=sMarks.isEmpty?0: sMarks.map((e)=> (e['mark'] as num).toDouble()).reduce((a,b)=>a+b)/sMarks.length;
    final pdf=pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (c)=>[
      pw.Center(child: pw.Text("BUSALAMU SECONDARY SCHOOL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:16))),
      pw.Center(child: pw.Text("$selTerm $selExam MERGED REPORT - $selClass $selStream", style: pw.TextStyle(fontSize:11))),
      pw.SizedBox(height:10),
      pw.Text("Name: $sname | ID: $sid | Avg: ${avg.toStringAsFixed(1)} | Grade: ${UNEBGrading.gradeOnly(grading, avg)} | ${sMarks.length}/${expectedSubs.length} subjects"),
      pw.SizedBox(height:8),
      pw.Table.fromTextArray(headers: ["Subject","Mark","Grade","Teacher"], data: sMarks.map((m)=> [m['subject'].toString(), m['mark'].toString(), UNEBGrading.gradeOnly(grading, (m['mark'] as num).toDouble()), (m['teacherName']??'').toString()]).toList(), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize:9), headerDecoration: pw.BoxDecoration(color: PdfColors.indigo)),
      if(expectedSubs.length!=sMarks.length) pw.Text("Missing: ${expectedSubs.where((s)=>!sMarks.any((m)=> m['subject']==s)).join(', ')}", style: pw.TextStyle(color: PdfColors.red, fontSize:9)),
    ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "${sname}_merged.pdf");
  }

  Future<void> exportExcel() async {
    var excel = Excel.createExcel();
    var sheet = excel['${selClass}_${selStream}'];
    sheet.appendRow([TextCellValue("Pos"),TextCellValue("Name"),TextCellValue("ID"),TextCellValue("Subs"),TextCellValue("Avg"),TextCellValue("Grade"),...expectedSubs.map((s)=> TextCellValue(s))]);
    List<Map<String,dynamic>> ranked=[];
    for(var s in students){
      String sid=s['idNo']??'';
      var sm=allMarks.where((e)=> e['studentId']==sid).toList();
      double total=sm.isEmpty?0: sm.map((e)=> (e['mark'] as num).toDouble()).reduce((a,b)=>a+b);
      double avg=sm.isEmpty?0: total/sm.length;
      ranked.add({...s, 'avg':avg, 'count':sm.length, 'marks':sm});
    }
    ranked.sort((a,b)=> (b['avg'] as double).compareTo(a['avg'] as double));
    for(int i=0;i<ranked.length;i++){
      var s=ranked[i];
      Map<String,dynamic> mm={for(var m in s['marks']) m['subject'].toString(): m['mark']};
      sheet.appendRow([IntCellValue(i+1),TextCellValue(s['name'].toString()),TextCellValue(s['idNo'].toString()),IntCellValue(s['count']),DoubleCellValue(s['avg']),TextCellValue(UNEBGrading.gradeOnly(grading, s['avg'])),...expectedSubs.map((sub)=> TextCellValue((mm[sub]??"MISSING").toString()))]);
    }
    var bytes = excel.save();
    if(bytes!=null) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: "${selClass}_${selStream}_marks.xlsx");
    }
  }

  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: Text("HT Dashboard - Merged Reports"), backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white, actions: [if(students.isNotEmpty) IconButton(icon: Icon(Icons.table_chart), onPressed: exportExcel), if(students.isNotEmpty) IconButton(icon: Icon(Icons.print), onPressed: () async { final pdf=pw.Document(); pdf.addPage(pw.Page(build: (c)=> pw.Text("Overall ${selClass} ${selStream}"))); await Printing.layoutPdf(onLayout: (f) async => pdf.save()); })]),
      body: ListView(padding: EdgeInsets.all(12), children: [
        DropdownButtonFormField<String>(value: selClass, decoration: InputDecoration(labelText: "Class", border: OutlineInputBorder(), isDense:true), items: classes.map((e)=> DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v){ setState(()=> selClass=v); if(v!=null) loadStreams(v); }),
        SizedBox(height:8),
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: selStream, decoration: InputDecoration(labelText: isALevel? "Combination (Sciences/Arts)" : "Stream (Blue/Red)", border: OutlineInputBorder(), isDense:true), items: streams.map((e)=> DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: loadingStreams? null : (v)=> setState(()=> selStream=v))), if(loadingStreams) Padding(padding: EdgeInsets.only(left:8), child: SizedBox(width:16,height:16, child: CircularProgressIndicator(strokeWidth:2))) ]),
        SizedBox(height:8),
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: selTerm, decoration: InputDecoration(labelText: "Term", border: OutlineInputBorder(), isDense:true), items: ["Term I 2026","Term II 2026","Term III 2026"].map((e)=> DropdownMenuItem(value:e, child: Text(e, style: TextStyle(fontSize:11)))).toList(), onChanged: (v)=> setState(()=> selTerm=v))), SizedBox(width:6), Expanded(child: DropdownButtonFormField<String>(value: selExam, decoration: InputDecoration(labelText: "Exam", border: OutlineInputBorder(), isDense:true), items: ["BOT","MID","EOT"].map((e)=> DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v)=> setState(()=> selExam=v)))]),
        SizedBox(height:10),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1), foregroundColor: Colors.white), onPressed: loadData, child: Text("LOAD CLASS - Show Missing & Filled")),
        if(loading) LinearProgressIndicator(),
        if(!loading && students.isNotEmpty)...[
          SizedBox(height:10),
          Card(color: Colors.indigo.shade50, child: Padding(padding: EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Expected Subjects: ${expectedSubs.join(', ')} (${expectedSubs.length}) ${tt.isEmpty? '(from entered marks - set Timetable Grid for accuracy)' : '(from Timetable Grid)'}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:11)),
            SizedBox(height:4),
            Text("Students: ${students.length} | Entered: ${allMarks.length} / ${students.length*expectedSubs.length} | Missing: ${students.length*expectedSubs.length - allMarks.length}", style: TextStyle(fontSize:10, color: Colors.red, fontWeight: FontWeight.bold)),
            SizedBox(height:6),
           ...expectedSubs.map((sub){ int entered=allMarks.where((m)=> m['subject']==sub).length; int miss=students.length-entered; return Text("$sub: $entered/${students.length} ${miss>0? '❌ $miss missing' : '✅ Complete'}", style: TextStyle(fontSize:10, color: miss>0? Colors.red : Colors.green)); }),
          ]))),
         ...students.map((s){ String sid=s['idNo']??''; String name=s['name']??''; var sm=allMarks.where((e)=> e['studentId']==sid).toList(); double avg=sm.isEmpty?0: sm.map((e)=> (e['mark'] as num).toDouble()).reduce((a,b)=>a+b)/sm.length; var missing=expectedSubs.where((sub)=>!sm.any((m)=> m['subject']==sub)).toList(); return Card(color: missing.isEmpty? Colors.white : Colors.red.shade50, child: ListTile(dense:true, title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), subtitle: Text("${sm.length}/${expectedSubs.length} | Avg ${avg.toStringAsFixed(1)} | ${UNEBGrading.gradeOnly(grading, avg)} | ${missing.isEmpty? 'Complete ✅' : 'Missing: ${missing.join(', ')} ❌'}", style: TextStyle(fontSize:10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.picture_as_pdf, color: Colors.red, size:20), onPressed: ()=> printMerged(sid, name)), IconButton(icon: Icon(Icons.chat, color: Colors.green, size:20), onPressed: () async { String phone=s['parentPhone']??''; if(phone.isEmpty) return; String clean=phone.replaceAll(RegExp(r'[^0-9]'), ''); if(clean.startsWith('0')) clean='256${clean.substring(1)}'; String msg="Busalamu $selTerm $selExam $name Avg:${avg.toStringAsFixed(1)} Grade:${UNEBGrading.gradeOnly(grading, avg)} ${sm.length}/${expectedSubs.length}"; final uri=Uri.parse("https://wa.me/$clean?text=${Uri.encodeComponent(msg)}"); if(await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); })]))); }),
        ],
        if(!loading && selClass!=null && students.isEmpty && selStream!=null) Padding(padding: EdgeInsets.all(20), child: Text("No students for $selClass $selStream. Add students first.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
      ]),
    );
  }
}