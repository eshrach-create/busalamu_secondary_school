import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyB8EzY9nAynlgkecISluHg_jyglWx5JcEo",
      authDomain: "busalamu-bss-gob.firebaseapp.com",
      projectId: "busalamu-bss-gob",
      storageBucket: "busalamu-bss-gob.firebasestorage.app",
      messagingSenderId: "658395019508",
      appId: "1:658395019508:web:2a96d09bc2aed54fd006a1",
      measurementId: "G-EXM70J3F9Z"
    )
  );
  runApp(BusalamuApp());
}

class BusalamuApp extends StatelessWidget {
  @override Widget build(BuildContext c) => MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage());
}

class ZoneAccess {
  DateTime issued; int days;
  ZoneAccess({required this.issued, required this.days});
  int get left => issued.add(Duration(days: days)).difference(DateTime.now()).inDays;
  bool get expired => left < 0;
  Map<String,dynamic> toMap()=>{'issued':issued.toIso8601String(),'days':days};
  static ZoneAccess fromMap(Map m)=>ZoneAccess(issued: DateTime.parse(m['issued']), days: m['days']);
}

class Student {
  String name, cls, stream, idNo;
  Map<String, ZoneAccess> zones;
  bool selected=false; bool present=false;
  Student({required this.name, required this.cls, required this.stream, required this.idNo, required this.zones});
  Map<String,dynamic> toMap()=>{'name':name,'cls':cls,'stream':stream,'idNo':idNo,'zones':zones.map((k,v)=>MapEntry(k,v.toMap()))};
  static Student fromMap(Map m){
    Map<String,ZoneAccess> z={};
    (m['zones'] as Map).forEach((k,v)=>z[k]=ZoneAccess.fromMap(v));
    return Student(name:m['name'],cls:m['cls'],stream:m['stream'],idNo:m['idNo'],zones:z);
  }
}

class ClassTeacher { String cls, stream, name, whatsapp, subject; ClassTeacher({required this.cls, required this.stream, required this.name, required this.whatsapp, required this.subject}); Map<String,dynamic> toMap()=>{'cls':cls,'stream':stream,'name':name,'whatsapp':whatsapp,'subject':subject}; static ClassTeacher fromMap(Map m)=>ClassTeacher(cls:m['cls'],stream:m['stream'],name:m['name'],whatsapp:m['whatsapp'],subject:m['subject']); }
class Timetable { String id; String day, period, cls, stream, subject, teacher, time; bool isBreak; Timetable({required this.id, required this.day, required this.period, required this.cls, required this.stream, required this.subject, required this.teacher, required this.time, this.isBreak=false}); Map<String,dynamic> toMap()=>{'id':id,'day':day,'period':period,'cls':cls,'stream':stream,'subject':subject,'teacher':teacher,'time':time,'isBreak':isBreak}; static Timetable fromMap(Map m)=>Timetable(id:m['id'],day:m['day'],period:m['period'],cls:m['cls'],stream:m['stream'],subject:m['subject'],teacher:m['teacher'],time:m['time'],isBreak:m['isBreak']??false); }
class AttendanceLog { String idNo, cls, stream, date, period, status; AttendanceLog({required this.idNo, required this.cls, required this.stream, required this.date, required this.period, required this.status}); Map<String,dynamic> toMap()=>{'idNo':idNo,'cls':cls,'stream':stream,'date':date,'period':period,'status':status,'ts':FieldValue.serverTimestamp()}; static AttendanceLog fromMap(Map m)=>AttendanceLog(idNo:m['idNo'],cls:m['cls'],stream:m['stream'],date:m['date'],period:m['period'],status:m['status']); }
class AppUser { String email,pass,role,name; String studentId; AppUser({required this.email,required this.pass,required this.role,required this.name, this.studentId=''}); }

class LoginPage extends StatefulWidget { @override _LoginPageState createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final eC=TextEditingController(text:'ht@busalamu.com');
  final pC=TextEditingController(text:'ht123');
  String err='';
  List<AppUser> users=[
    AppUser(email:'ht@busalamu.com',pass:'ht123',role:'HT',name:'Headteacher'),
    AppUser(email:'teacher@busalamu.com',pass:'teacher123',role:'TEACHER',name:'Gate Teacher'),
    AppUser(email:'student@busalamu.com',pass:'student123',role:'STUDENT',name:'Student', studentId:'BSS/2026/022'),
  ];
  @override Widget build(BuildContext c){
    return Scaffold(backgroundColor: Color(0xFF0D47A1), body: Center(child: Card(margin: EdgeInsets.all(20), child: Padding(padding: EdgeInsets.all(25), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/badge.png', height: 90, width: 90, errorBuilder: (c,e,s)=>Icon(Icons.school,size:70,color: Color(0xFF0D47A1))),
      SizedBox(height: 10),
      Text('BSS GoB The Great',style: TextStyle(fontWeight: FontWeight.bold,fontSize:18,color: Color(0xFF0D47A1))),
      Text('REAL QR CAMERA + LIVE SYNC',style: TextStyle(fontSize:10,color: Colors.green,fontWeight: FontWeight.bold)),
      SizedBox(height:15),
      TextField(controller: eC,decoration: InputDecoration(labelText:'Email',border: OutlineInputBorder())),
      SizedBox(height:10),
      TextField(controller: pC,obscureText:true,decoration: InputDecoration(labelText:'Password',border: OutlineInputBorder())),
      if(err.isNotEmpty) Text(err,style: TextStyle(color: Colors.red)),
      SizedBox(height:15),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1)), onPressed: (){
        try{
          var u=users.firstWhere((x)=>x.email==eC.text.trim()&&x.pass==pC.text.trim());
          Navigator.pushReplacement(c, MaterialPageRoute(builder:(_)=>MainScreen(cur:u)));
        }catch(_){ setState(()=>err='Wrong login'); }
      }, child: Text('LOGIN')))
    ])))));
  }
}

class MainScreen extends StatefulWidget { final AppUser cur; MainScreen({required this.cur}); @override _MainScreenState createState()=>_MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  int idx=0;
  List<Student> studs=[];
  List<ClassTeacher> teachers=[];
  List<Timetable> timetable=[];
  List<AttendanceLog> logs=[];
  bool loading=true;
  final db=FirebaseFirestore.instance;

  @override void initState(){
    super.initState();
    _seedIfEmpty();
    db.collection('students').snapshots().listen((snap){ setState((){ studs=snap.docs.map((d)=>Student.fromMap(d.data())).toList(); loading=false; }); });
    db.collection('attendance_logs').orderBy('ts',descending:true).limit(500).snapshots().listen((snap){ setState(()=>logs=snap.docs.map((d)=>AttendanceLog.fromMap(d.data())).toList()); });
    db.collection('teachers').snapshots().listen((snap){ setState(()=>teachers=snap.docs.map((d)=>ClassTeacher.fromMap(d.data())).toList()); });
    db.collection('timetable').snapshots().listen((snap){ setState(()=>timetable=snap.docs.map((d)=>Timetable.fromMap(d.data())).toList()); });
  }

  Future<void> _seedIfEmpty() async {
    var s=await db.collection('students').limit(1).get();
    if(s.docs.isEmpty){
      List<Student> init=[
        Student(name:'Quin Ton Tavius',cls:'S.4',stream:'Blue',idNo:'BSS/2026/022',zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:30),'CLASS':ZoneAccess(issued:DateTime.now(),days:90),'MESS':ZoneAccess(issued:DateTime.now(),days:60)}),
        Student(name:'Nabirye Sarah',cls:'S.4',stream:'Blue',idNo:'BSS/2026/023',zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:-2),'CLASS':ZoneAccess(issued:DateTime.now(),days:90),'MESS':ZoneAccess(issued:DateTime.now(),days:-2)}),
        Student(name:'Okello John',cls:'S.4',stream:'Red',idNo:'BSS/2026/024',zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:25),'CLASS':ZoneAccess(issued:DateTime.now(),days:10),'MESS':ZoneAccess(issued:DateTime.now(),days:30)}),
      ];
      for(var st in init){ await db.collection('students').doc(st.idNo).set(st.toMap()); }
    }
  }

  Future<void> syncStudent(Student s) async => await db.collection('students').doc(s.idNo).set(s.toMap());
  Future<void> syncLog(AttendanceLog l) async => await db.collection('attendance_logs').add(l.toMap());
  Future<void> syncTeacher(ClassTeacher t) async => await db.collection('teachers').doc('${t.cls}_${t.stream}_${t.name}').set(t.toMap());
  Future<void> syncTimetable(Timetable t) async => await db.collection('timetable').doc(t.id).set(t.toMap());

  void grant(int i,int days){ var s=studs[i]; s.zones={'GATE':ZoneAccess(issued:DateTime.now(),days:days),'CLASS':ZoneAccess(issued:DateTime.now(),days:days),'MESS':ZoneAccess(issued:DateTime.now(),days:days)}; syncStudent(s); }
  void grantMulti(List<int> ids,int days){ for(var i in ids){ grant(i,days); } }

  Future<void> whatsapp(Student s,String zone) async {
    var t=teachers.firstWhere((e)=>e.cls==s.cls&&e.stream==s.stream, orElse: ()=>ClassTeacher(cls:s.cls,stream:s.stream,name:'HT',whatsapp:'256700000000',subject:''));
    String txt='BUSALAMU ALERT: ${s.name} DENIED $zone';
    String url='https://wa.me/${t.whatsapp}?text=${Uri.encodeComponent(txt)}';
    try{ if(await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }catch(_){}
  }

  @override Widget build(BuildContext c){
    if(loading) return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), Text('Connecting Real-Time Camera...')])));
    bool isHT=widget.cur.role=='HT';
    bool isStudent=widget.cur.role=='STUDENT';
    List<Widget> pages=[];
    List<BottomNavigationBarItem> nav=[];
    if(isStudent){
      var my=studs.firstWhere((s)=>s.idNo==widget.cur.studentId, orElse: ()=>studs.isNotEmpty? studs[0] : Student(name:'Test',cls:'S.4',stream:'Blue',idNo:'BSS/2026/022',zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:30),'CLASS':ZoneAccess(issued:DateTime.now(),days:90),'MESS':ZoneAccess(issued:DateTime.now(),days:60)}));
      pages=[StudentPortal(student:my,logs:logs), StudentQR(student:my,logs:logs)];
      nav=[BottomNavigationBarItem(icon: Icon(Icons.person),label:'My Days'), BottomNavigationBarItem(icon: Icon(Icons.qr_code),label:'My QR')];
    } else if(isHT){
      pages=[HTDash(studs:studs), GateReal(studs:studs,onDeny:whatsapp), AttendReal(studs:studs,timetable:timetable,logs:logs,onSyncLog:syncLog,onSyncStudent:syncStudent), IDGrid(studs:studs), StudentsPage(studs:studs,onSync:syncStudent), TeachersPage(teachers:teachers,onSync:syncTeacher,db:db), TimeTablePage(timetable:timetable,onSync:syncTimetable,db:db), ReportsPage(studs:studs,logs:logs), Setup(studs:studs,onGrantSingle:grant,onGrantMulti:grantMulti)];
      nav=[BottomNavigationBarItem(icon: Icon(Icons.dashboard),label:'HT'), BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),label:'Gate CAM'), BottomNavigationBarItem(icon: Icon(Icons.how_to_reg),label:'Attend CAM'), BottomNavigationBarItem(icon: Icon(Icons.badge),label:'IDs'), BottomNavigationBarItem(icon: Icon(Icons.people_alt),label:'Students'), BottomNavigationBarItem(icon: Icon(Icons.people),label:'Teachers'), BottomNavigationBarItem(icon: Icon(Icons.schedule),label:'Timetable'), BottomNavigationBarItem(icon: Icon(Icons.analytics),label:'Reports'), BottomNavigationBarItem(icon: Icon(Icons.settings),label:'Setup')];
    } else {
      pages=[GateReal(studs:studs,onDeny:whatsapp), AttendReal(studs:studs,timetable:timetable,logs:logs,onSyncLog:syncLog,onSyncStudent:syncStudent), IDGrid(studs:studs), TimeTablePage(timetable:timetable,readOnly:true,onSync:syncTimetable,db:db)];
      nav=[BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),label:'Gate CAM'), BottomNavigationBarItem(icon: Icon(Icons.how_to_reg),label:'Attend CAM'), BottomNavigationBarItem(icon: Icon(Icons.badge),label:'IDs'), BottomNavigationBarItem(icon: Icon(Icons.schedule),label:'Timetable')];
    }
    if(idx>=pages.length) idx=0;
    return Scaffold(appBar: AppBar(title: Text('${widget.cur.role}: ${widget.cur.name} - CAM LIVE'), backgroundColor: Color(0xFF0D47A1), actions: [Icon(Icons.videocam,color: Colors.greenAccent), Icon(Icons.cloud_done,color: Colors.white), SizedBox(width:8), IconButton(icon: Icon(Icons.logout), onPressed: (){ Navigator.pushReplacement(c, MaterialPageRoute(builder:(_)=>LoginPage())); })]), body: pages[idx], bottomNavigationBar: BottomNavigationBar(currentIndex: idx, onTap: (i)=>setState(()=>idx=i), type: BottomNavigationBarType.fixed, selectedItemColor: Color(0xFF0D47A1), items: nav));
  }
}

class HTDash extends StatelessWidget {
  final List<Student> studs; HTDash({required this.studs});
  @override Widget build(BuildContext c){
    var alert=studs.where((s)=>s.zones.values.any((z)=>z.left<=0&&z.left>=-2)).toList();
    return ListView(padding: EdgeInsets.all(15), children: [
      Card(color: Colors.green[50], child: Padding(padding: EdgeInsets.all(8), child: Row(children: [Icon(Icons.qr_code_scanner,color: Colors.green), SizedBox(width:8), Text('REAL QR CAMERA + LIVE SYNC ACTIVE',style: TextStyle(fontWeight: FontWeight.bold,fontSize:11))]))),
      Text('HT DASHBOARD',style: TextStyle(fontWeight: FontWeight.bold,fontSize:18,color: Color(0xFF0D47A1))),
      if(alert.isNotEmpty) Card(color: Colors.red[50], child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ALERT: Special Access Ended!',style: TextStyle(color: Colors.red,fontWeight: FontWeight.bold)),...alert.map((s)=>Text('${s.name} GATE ${s.zones['GATE']!.left}d ENDED')).toList()]))),
      Card(child: ListTile(title: Text('Total ${studs.length} Students - RealTime Camera Ready'))),
    ]);
  }
}

class StudentPortal extends StatelessWidget {
  final Student student; final List<AttendanceLog> logs; StudentPortal({required this.student, required this.logs});
  @override Widget build(BuildContext c){
    var my=logs.where((l)=>l.idNo==student.idNo).toList();
    int p=my.where((l)=>l.status=='PRESENT').length; int a=my.where((l)=>l.status!='PRESENT').length;
    return ListView(padding: EdgeInsets.all(15), children: [
      Card(color: Colors.blue[50], child: Padding(padding: EdgeInsets.all(15), child: Column(children: [Icon(Icons.person,size:50,color: Color(0xFF0D47A1)), Text('My Attendance LIVE',style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [Text('$p',style: TextStyle(fontSize:28,color: Colors.green,fontWeight: FontWeight.bold)), Text('Present')])))), Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [Text('$a',style: TextStyle(fontSize:28,color: Colors.red,fontWeight: FontWeight.bold)), Text('Absent')]))))])]))),
 ...my.map((l)=>Card(child: ListTile(leading: Icon(l.status=='PRESENT'?Icons.check_circle:Icons.cancel,color: l.status=='PRESENT'?Colors.green:Colors.red), title: Text('${l.date} ${l.period} ${l.status}')))).toList()
    ]);
  }
}
class StudentQR extends StatefulWidget { final Student student; final List<AttendanceLog> logs; StudentQR({required this.student, required this.logs}); @override _StudentQRState createState()=>_StudentQRState(); }
class _StudentQRState extends State<StudentQR> {
  String? result;
  @override Widget build(BuildContext c){
    var my=widget.logs.where((l)=>l.idNo==widget.student.idNo).toList();
    int p=my.where((l)=>l.status=='PRESENT').length; int a=my.where((l)=>l.status!='PRESENT').length;
    String qr='BUSALAMU|${widget.student.idNo}|GATE:${widget.student.zones['GATE']!.left}d';
    return Padding(padding: EdgeInsets.all(15), child: Column(children: [
      Card(child: Padding(padding: EdgeInsets.all(15), child: Column(children: [QrImageView(data: qr,size:180), Text(widget.student.idNo,style: TextStyle(fontWeight: FontWeight.bold))]))),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1)), onPressed: (){ setState(()=>result='Present: $p days, Absent: $a days (LIVE)'); }, child: Text('SCAN MY QR - View My Days')),
      if(result!=null) Card(color: Colors.green[50], child: Padding(padding: EdgeInsets.all(12), child: Text(result!,style: TextStyle(fontWeight: FontWeight.bold)))),
    ]));
  }
}

class GateReal extends StatefulWidget { final List<Student> studs; final Function(Student,String) onDeny; GateReal({required this.studs, required this.onDeny}); @override _GateRealState createState()=>_GateRealState(); }
class _GateRealState extends State<GateReal> {
  String zone='GATE'; bool? ok; String msg='Ready - Point camera to Student ID QR'; final ctrl=TextEditingController();
  MobileScannerController scannerController = MobileScannerController();
  bool isScanning=false;
  void verify(String code){
    String id=code.split('|').length>1?code.split('|')[1]:code;
    var s=widget.studs.firstWhere((e)=>code.contains(e.idNo)||id.contains(e.idNo), orElse: ()=>Student(name:'Unknown',cls:'?',stream:'?',idNo:id,zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:0),'CLASS':ZoneAccess(issued:DateTime.now(),days:0),'MESS':ZoneAccess(issued:DateTime.now(),days:0)}));
    bool valid=s.zones[zone]!=null&&!s.zones[zone]!.expired;
    setState((){ ok=valid; msg='${s.name} ${s.cls} ${s.stream} ${zone}:${s.zones[zone]?.left}d'; isScanning=false; });
    scannerController.stop();
    if(!valid&&s.name!='Unknown') widget.onDeny(s,zone);
  }
  @override void dispose(){ scannerController.dispose(); super.dispose(); }
  @override Widget build(BuildContext c)=>Scaffold(
    appBar: AppBar(title: Text('Gate $zone - CAMERA'),backgroundColor: Color(0xFF0D47A1), actions: [IconButton(icon: Icon(isScanning?Icons.close:Icons.qr_code_scanner), onPressed: (){ if(isScanning){ scannerController.stop(); } else { scannerController.start(); } setState(()=>isScanning=!isScanning); })]),
    body: Column(children: [
      Padding(padding: EdgeInsets.all(8), child: DropdownButton<String>(value: zone,isExpanded:true,items: ['GATE','CLASS','MESS'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>setState(()=>zone=v!))),
      if(isScanning) Expanded(flex:3, child: Stack(children: [MobileScanner(controller: scannerController, onDetect: (capture){ for(final barcode in capture.barcodes){ if(barcode.rawValue!=null){ verify(barcode.rawValue!); } } }), Center(child: Container(width: 200, height: 200, decoration: BoxDecoration(border: Border.all(color: Colors.green,width:3), borderRadius: BorderRadius.circular(12))),), Positioned(bottom:10, left:0, right:0, child: Center(child: Container(color: Colors.black54, padding: EdgeInsets.all(6), child: Text('Point to Student QR ID',style: TextStyle(color: Colors.white)))))])),
      if(!isScanning) Padding(padding: EdgeInsets.all(12), child: Column(children: [
        TextField(controller: ctrl,decoration: InputDecoration(labelText:'Or Type QR Manually',border: OutlineInputBorder()), onSubmitted: verify),
        SizedBox(height:8),
        Row(children: [
          Expanded(child: ElevatedButton.icon(icon: Icon(Icons.qr_code_scanner),label: Text('OPEN CAMERA'),style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1)), onPressed: (){ setState(()=>isScanning=true); scannerController.start(); })),
          SizedBox(width:8),
          Expanded(child: ElevatedButton.icon(icon: Icon(Icons.camera_alt),label: Text('SIM'), onPressed: (){ var r=(widget.studs..shuffle()).first; String f='BUSALAMU|${r.idNo}|GATE:${r.zones['GATE']!.left}d'; ctrl.text=f; verify(f); })),
        ]),
        if(ok!=null) Container(margin: EdgeInsets.only(top:12),padding: EdgeInsets.all(16),color: ok!?Colors.green[50]:Colors.red[50], child: Column(children: [Icon(ok!?Icons.verified:Icons.block,size:50,color: ok!?Colors.green:Colors.red), Text(ok!?'ALLOWED':'DENIED',style: TextStyle(fontWeight: FontWeight.bold,fontSize:18)), Text(msg)]))
      ]))
    ]));
}

class AttendReal extends StatefulWidget { final List<Student> studs; final List<Timetable> timetable; final List<AttendanceLog> logs; final Function(AttendanceLog) onSyncLog; final Function(Student) onSyncStudent; AttendReal({required this.studs, required this.timetable, required this.logs, required this.onSyncLog, required this.onSyncStudent}); @override _AttendRealState createState()=>_AttendRealState(); }
class _AttendRealState extends State<AttendReal> {
  String selClass='S.4'; String selStream='Blue'; DateTime from=DateTime.now().subtract(Duration(days:7)); DateTime to=DateTime.now();
  List<String> classes=['S.1','S.2','S.3','S.4','S.5','S.6'];
  List<String> get streams => (selClass=='S.5'||selClass=='S.6')? ['Sciences','Arts'] : ['Blue','Red'];
  MobileScannerController scannerController = MobileScannerController();
  bool isScanning=false;

  List<AttendanceLog> get filteredLogs => widget.logs.where((l){ if(l.cls!=selClass) return false; if(l.stream!=selStream) return false; try{ DateTime d=DateTime.parse(l.date); return d.isAfter(from.subtract(Duration(days:1))) && d.isBefore(to.add(Duration(days:1))); }catch(_){ return true; } }).toList();
  List<Student> get filteredStudents => widget.studs.where((s)=>s.cls==selClass&&s.stream==selStream).toList();

  void mark(String code){
    String id=code.split('|').length>1?code.split('|')[1]:code;
    int idx=widget.studs.indexWhere((s)=>code.contains(s.idNo)||id.contains(s.idNo));
    if(idx!=-1){
      setState(()=>widget.studs[idx].present=true);
      var log=AttendanceLog(idNo:widget.studs[idx].idNo,cls:selClass,stream:selStream,date:DateTime.now().toString().split(' ')[0],period:'P1',status:'PRESENT');
      widget.onSyncLog(log);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.studs[idx].name} PRESENT - LIVE SYNCED!'), backgroundColor: Colors.green));
    }
  }

  Future<void> exportPdf(bool present) async {
    var logsToExport=filteredLogs.where((l)=> present? l.status=='PRESENT' : l.status!='PRESENT').toList();
    if(logsToExport.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No ${present?'Present':'Absent'} data'))); return; }
    final pdf=pw.Document();
    pdf.addPage(pw.Page(build: (c)=>pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('BSS GoB The Great - ${present?'PRESENT':'ABSENT'} CAM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('Class: $selClass Stream: $selStream From: ${from.toString().split(' ')[0]} To: ${to.toString().split(' ')[0]}'),
      pw.SizedBox(height:10),
      pw.Table.fromTextArray(headers: ['Date','Period','ID','Name','Status'], data: logsToExport.map((l){ var s=widget.studs.firstWhere((e)=>e.idNo==l.idNo, orElse: ()=>Student(name:'?',cls:l.cls,stream:l.stream,idNo:l.idNo,zones:{})); return [l.date,l.period,l.idNo,s.name,l.status]; }).toList())
    ])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  @override void dispose(){ scannerController.dispose(); super.dispose(); }

  @override Widget build(BuildContext c){
    var filtered=filteredStudents;
    var presentLogs=filteredLogs.where((l)=>l.status=='PRESENT').length;
    var absentLogs=filteredLogs.where((l)=>l.status!='PRESENT').length;
    return Scaffold(
      appBar: AppBar(title: Text('Attend $selClass $selStream - CAM'),backgroundColor: Color(0xFF0D47A1), actions: [IconButton(icon: Icon(Icons.qr_code_scanner), onPressed: (){ setState(()=>isScanning=!isScanning); if(isScanning) scannerController.start(); else scannerController.stop(); })]),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(heroTag:'p', backgroundColor: Colors.green, icon: Icon(Icons.picture_as_pdf), label: Text('Export PRESENT PDF ($presentLogs)'), onPressed: ()=>exportPdf(true)),
        SizedBox(height:6),
        FloatingActionButton.extended(heroTag:'a', backgroundColor: Colors.red, icon: Icon(Icons.picture_as_pdf), label: Text('Export ABSENT PDF ($absentLogs)'), onPressed: ()=>exportPdf(false)),
      ]),
      body: Column(children: [
        if(isScanning) Container(height: 280, child: Stack(children: [MobileScanner(controller: scannerController, onDetect: (capture){ for(final b in capture.barcodes){ if(b.rawValue!=null){ mark(b.rawValue!); } } }), Center(child: Container(width:200,height:200,decoration: BoxDecoration(border: Border.all(color: Colors.green,width:3))))])),
        Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: DropdownButton<String>(value: selClass,isExpanded:true,items: classes.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>setState(()=>selClass=v!))), SizedBox(width:6), Expanded(child: DropdownButton<String>(value: selStream,isExpanded:true,items: streams.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>setState(()=>selStream=v!)))])),
        Padding(padding: EdgeInsets.symmetric(horizontal:8), child: Column(children: [
          Card(color: Colors.blue[50], child: Padding(padding: EdgeInsets.all(8), child: Column(children: [Text('From...To... Filter',style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [Expanded(child: ElevatedButton(onPressed: () async { var d=await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2025), lastDate: DateTime(2028)); if(d!=null) setState(()=>from=d); }, child: Text('From ${from.toString().split(' ')[0]}'))), SizedBox(width:6), Expanded(child: ElevatedButton(onPressed: () async { var d=await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2025), lastDate: DateTime(2028)); if(d!=null) setState(()=>to=d); }, child: Text('To ${to.toString().split(' ')[0]}')))]), Text('P:$presentLogs A:$absentLogs LIVE',style: TextStyle(fontWeight: FontWeight.bold))]))),
          ElevatedButton.icon(icon: Icon(Icons.qr_code_scanner), label: Text('SCAN STUDENT ID WITH CAMERA - AUTO PRESENT'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0D47A1)), onPressed: (){ setState(()=>isScanning=true); scannerController.start(); }),
        ])),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (c,i){ var s=filtered[i]; int absCount=filteredLogs.where((l)=>l.idNo==s.idNo&&l.status!='PRESENT').length; return Card(child: ListTile(title: Text(s.name), subtitle: Text('${s.idNo} Absent in range: $absCount'), trailing: Checkbox(value: s.present, onChanged: (v){ setState(()=>s.present=v!); if(v==true){ widget.onSyncLog(AttendanceLog(idNo:s.idNo,cls:selClass,stream:selStream,date:DateTime.now().toString().split(' ')[0],period:'P1',status:'PRESENT')); } }))); })),
        SizedBox(height:140)
      ])
    );
  }
}

class IDGrid extends StatefulWidget { final List<Student> studs; IDGrid({required this.studs}); @override _IDGridState createState()=>_IDGridState(); }
class _IDGridState extends State<IDGrid> {
  String filterClass='All'; String filterStream='All'; bool selectMode=false;
  List<String> classes=['All','S.1','S.2','S.3','S.4','S.5','S.6'];
  List<String> get streams => (filterClass=='S.5'||filterClass=='S.6')? ['All','Sciences','Arts'] : ['All','Blue','Red'];
  List<Student> get list { var l=widget.studs; if(filterClass!='All') l=l.where((s)=>s.cls==filterClass).toList(); if(filterStream!='All') l=l.where((s)=>s.stream==filterStream).toList(); return l; }

  Future<void> exportPdf(bool all) async {
    List<Student> toExport=all? list : list.where((s)=>s.selected).toList();
    if(toExport.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select IDs first'))); return; }
    final pdf=pw.Document();
    var format = PdfPageFormat(144, 144, marginAll: 5);
    for(var s in toExport){
      String qr='BUSALAMU|${s.idNo}|GATE:${s.zones['GATE']!.left}d';
      pdf.addPage(pw.Page(pageFormat: format, build: (ctx)=>pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width:1)), padding: pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text('BSS GoB The Great', style: pw.TextStyle(fontSize:6, fontWeight: pw.FontWeight.bold)),
        pw.Text(s.name, style: pw.TextStyle(fontSize:7, fontWeight: pw.FontWeight.bold)),
        pw.Text('${s.cls} ${s.stream}', style: pw.TextStyle(fontSize:5)),
        pw.Text(s.idNo, style: pw.TextStyle(fontSize:5)),
        pw.SizedBox(height:3),
        pw.BarcodeWidget(data: qr, barcode: pw.Barcode.qrCode(), width: 60, height: 60),
        pw.SizedBox(height:2),
        pw.Text('GATE ${s.zones['GATE']!.left}d', style: pw.TextStyle(fontSize:5, fontWeight: pw.FontWeight.bold)),
      ]))));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: Text('IDs ${list.length} 2x2 inch'),backgroundColor: Color(0xFF0D47A1)),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(heroTag:'all', backgroundColor: Color(0xFF0D47A1), icon: Icon(Icons.picture_as_pdf), label: Text('PDF ALL 2inch (${list.length})'), onPressed: ()=>exportPdf(true)),
        SizedBox(height:6),
        FloatingActionButton.extended(heroTag:'sel', backgroundColor: Colors.green, icon: Icon(Icons.checklist), label: Text('PDF Selected (${list.where((s)=>s.selected).length})'), onPressed: ()=>exportPdf(false)),
      ]),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(8), child: Row(children: [
          Expanded(child: DropdownButton<String>(value: filterClass,isExpanded:true,items: classes.map((e)=>DropdownMenuItem(value:e,child:Text('Class: $e'))).toList(), onChanged: (v)=>setState(()=>filterClass=v!))),
          SizedBox(width:6),
          Expanded(child: DropdownButton<String>(value: filterStream,isExpanded:true,items: streams.map((e)=>DropdownMenuItem(value:e,child:Text('Stream: $e'))).toList(), onChanged: (v)=>setState(()=>filterStream=v!))),
          IconButton(icon: Icon(selectMode?Icons.close:Icons.checklist), onPressed: ()=>setState(()=>selectMode=!selectMode))
        ])),
        if(selectMode) Row(children: [Checkbox(value: list.isNotEmpty&&list.every((s)=>s.selected), onChanged: (v){ setState(()=>list.forEach((s)=>s.selected=v!)); }), Text('Select All')]),
        Expanded(child: GridView.builder(padding: EdgeInsets.all(8), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2, childAspectRatio:0.78, crossAxisSpacing:8, mainAxisSpacing:8), itemCount: list.length, itemBuilder: (c,i){
          var s=list[i];
          return Card(elevation:3, child: Padding(padding: EdgeInsets.all(8), child: Column(children: [
            if(selectMode) Checkbox(value: s.selected, onChanged: (v)=>setState(()=>s.selected=v!), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
            Text(s.name,style: TextStyle(fontWeight: FontWeight.bold,fontSize:11),maxLines:1),
            Text('${s.cls} ${s.stream} ${s.idNo}',style: TextStyle(fontSize:9)),
            QrImageView(data: 'BUSALAMU|${s.idNo}|GATE:${s.zones['GATE']!.left}d',size:85),
            Container(padding: EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: s.zones['GATE']!.expired?Colors.red[100]:Colors.green[100], borderRadius: BorderRadius.circular(4)), child: Text('GATE ${s.zones['GATE']!.left}d',style: TextStyle(fontSize:9,fontWeight: FontWeight.bold)))
          ])));
        })),
        SizedBox(height:130)
      ])
    );
  }
}

class StudentsPage extends StatefulWidget { final List<Student> studs; final Function(Student) onSync; StudentsPage({required this.studs, required this.onSync}); @override _StudentsPageState createState()=>_StudentsPageState(); }
class _StudentsPageState extends State<StudentsPage> {
  void addManual(){
    var name=TextEditingController(); var cls=TextEditingController(text:'S.4'); var stream=TextEditingController(text:'Blue'); var id=TextEditingController();
    showDialog(context: context, builder: (x)=>AlertDialog(title: Text('Add Student LIVE'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name,decoration: InputDecoration(labelText:'Name')), TextField(controller: cls,decoration: InputDecoration(labelText:'Class')), TextField(controller: stream,decoration: InputDecoration(labelText:'Stream')), TextField(controller: id,decoration: InputDecoration(labelText:'ID'))]), actions: [ElevatedButton(onPressed: (){ if(name.text.isNotEmpty&&id.text.isNotEmpty){ var s=Student(name:name.text,cls:cls.text,stream:stream.text,idNo:id.text,zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:30),'CLASS':ZoneAccess(issued:DateTime.now(),days:90),'MESS':ZoneAccess(issued:DateTime.now(),days:60)}); widget.onSync(s); Navigator.pop(x); } }, child: Text('Save LIVE'))]));
  }
  Future<void> exportExcel({bool empty=false}) async {
    var excel=Excel.createExcel();
    Sheet sheet=excel['Students'];
    sheet.appendRow([TextCellValue('Name'),TextCellValue('Class'),TextCellValue('Stream'),TextCellValue('ID No'),TextCellValue('GATE Days')]);
    if(!empty){ for(var s in widget.studs){ sheet.appendRow([TextCellValue(s.name),TextCellValue(s.cls),TextCellValue(s.stream),TextCellValue(s.idNo),IntCellValue(s.zones['GATE']!.left)]); } }
    else { sheet.appendRow([TextCellValue('Quin Ton Tavius'),TextCellValue('S.4'),TextCellValue('Blue'),TextCellValue('BSS/2026/022'),IntCellValue(30)]); }
    var bytes=excel.save();
    if(bytes!=null){ await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: empty? 'empty_template.xlsx' : 'students_export.xlsx'); }
  }
  Future<void> importExcel() async {
    try{
      FilePickerResult? result=await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if(result!=null && result.files.first.bytes!=null){
        var excel=Excel.decodeBytes(result.files.first.bytes!);
        var sheet=excel.tables[excel.tables.keys.first]!;
        int added=0;
        for(var i=1;i<sheet.maxRows;i++){
          var row=sheet.row(i);
          if(row.length>=4 && row[0]!=null){
            String name=row[0]!.value.toString(); String cls=row[1]?.value.toString()??'S.4'; String stream=row[2]?.value.toString()??'Blue'; String idNo=row[3]?.value.toString()??''; int days=int.tryParse(row.length>4? row[4]!.value.toString() : '30')?? 30;
            if(name.isNotEmpty && idNo.isNotEmpty &&!widget.studs.any((s)=>s.idNo==idNo)){ var s=Student(name:name,cls:cls,stream:stream,idNo:idNo,zones:{'GATE':ZoneAccess(issued:DateTime.now(),days:days),'CLASS':ZoneAccess(issued:DateTime.now(),days:days),'MESS':ZoneAccess(issued:DateTime.now(),days:days)}); widget.onSync(s); added++; }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $added LIVE')));
      }
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'))); }
  }
  @override Widget build(BuildContext c)=>Scaffold(
    appBar: AppBar(title: Text('Students ${widget.studs.length} LIVE'), backgroundColor: Color(0xFF0D47A1)),
    floatingActionButton: FloatingActionButton(child: Icon(Icons.person_add), backgroundColor: Color(0xFF0D47A1), onPressed: addManual),
    body: Column(children: [
      Card(margin: EdgeInsets.all(8), child: Padding(padding: EdgeInsets.all(8), child: Row(children: [
        Expanded(child: ElevatedButton.icon(icon: Icon(Icons.upload_file), label: Text('Import'), onPressed: importExcel)),
        SizedBox(width:6),
        Expanded(child: ElevatedButton.icon(icon: Icon(Icons.download), label: Text('Export All'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: ()=>exportExcel(empty:false))),
        SizedBox(width:6),
        Expanded(child: ElevatedButton.icon(icon: Icon(Icons.table_chart), label: Text('Template'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: ()=>exportExcel(empty:true))),
      ]))),
      Expanded(child: ListView.builder(itemCount: widget.studs.length, itemBuilder: (c,i){ var s=widget.studs[i]; return Card(child: ListTile(title: Text(s.name), subtitle: Text('${s.cls} ${s.stream} ${s.idNo} LIVE'), trailing: IconButton(icon: Icon(Icons.delete,color: Colors.red), onPressed: (){ FirebaseFirestore.instance.collection('students').doc(s.idNo).delete(); }))); }))
    ])
  );
}

class TeachersPage extends StatefulWidget { final List<ClassTeacher> teachers; final Function(ClassTeacher) onSync; final FirebaseFirestore db; TeachersPage({required this.teachers, required this.onSync, required this.db}); @override _TeachersPageState createState()=>_TeachersPageState(); }
class _TeachersPageState extends State<TeachersPage> {
  void addEdit({ClassTeacher? edit,int? idx}){
    var name=TextEditingController(text: edit?.name??''); var wa=TextEditingController(text: edit?.whatsapp??'2567'); var sub=TextEditingController(text: edit?.subject??''); var cls=TextEditingController(text: edit?.cls??'S.4'); var stream=TextEditingController(text: edit?.stream??'Blue');
    showDialog(context: context, builder: (x)=>AlertDialog(title: Text(edit==null?'Add':'Edit'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: cls,decoration: InputDecoration(labelText:'Class')), TextField(controller: stream,decoration: InputDecoration(labelText:'Stream')), TextField(controller: name,decoration: InputDecoration(labelText:'Name')), TextField(controller: wa,decoration: InputDecoration(labelText:'WhatsApp')), TextField(controller: sub,decoration: InputDecoration(labelText:'Subject'))]), actions: [ElevatedButton(onPressed: (){ var t=ClassTeacher(cls:cls.text,stream:stream.text,name:name.text,whatsapp:wa.text,subject:sub.text); widget.onSync(t); Navigator.pop(x); }, child: Text('Save LIVE'))]));
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: Text('Teachers LIVE'),backgroundColor: Color(0xFF0D47A1)), floatingActionButton: FloatingActionButton(child: Icon(Icons.person_add),backgroundColor: Color(0xFF0D47A1), onPressed: ()=>addEdit()), body: ListView.builder(padding: EdgeInsets.all(12), itemCount: widget.teachers.length, itemBuilder: (c,i){ var t=widget.teachers[i]; return Card(child: ListTile(title: Text('${t.cls} ${t.stream} ${t.name}'), subtitle: Text('${t.subject} ${t.whatsapp}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.edit,color: Colors.blue), onPressed: ()=>addEdit(edit:t,idx:i)), IconButton(icon: Icon(Icons.delete,color: Colors.red), onPressed: ()=>widget.db.collection('teachers').doc('${t.cls}_${t.stream}_${t.name}').delete())]))); }));
}

class TimeTablePage extends StatefulWidget { final List<Timetable> timetable; final bool readOnly; final Function(Timetable) onSync; final FirebaseFirestore db; TimeTablePage({required this.timetable,this.readOnly=false,required this.onSync,required this.db}); @override _TimeTablePageState createState()=>_TimeTablePageState(); }
class _TimeTablePageState extends State<TimeTablePage> {
  void addEdit({Timetable? edit}){
    var day=TextEditingController(text: edit?.day??'Monday'); var period=TextEditingController(text: edit?.period??'P1'); var time=TextEditingController(text: edit?.time??'08:00-08:40'); var sub=TextEditingController(text: edit?.subject??''); var teacher=TextEditingController(text: edit?.teacher??''); var cls=TextEditingController(text: edit?.cls??'S.4'); var stream=TextEditingController(text: edit?.stream??'Blue'); bool isBreak=edit?.isBreak??false;
    showDialog(context: context, builder: (x)=>StatefulBuilder(builder: (c2,setS)=>AlertDialog(title: Text(edit==null?'Add Period LIVE':'Edit Period LIVE'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: day,decoration: InputDecoration(labelText:'Day')), TextField(controller: period,decoration: InputDecoration(labelText:'Period')), TextField(controller: time,decoration: InputDecoration(labelText:'Time')), TextField(controller: sub,decoration: InputDecoration(labelText:'Subject')), TextField(controller: teacher,decoration: InputDecoration(labelText:'Teacher')), TextField(controller: cls,decoration: InputDecoration(labelText:'Class')), TextField(controller: stream,decoration: InputDecoration(labelText:'Stream')), CheckboxListTile(value: isBreak, onChanged: (v)=>setS(()=>isBreak=v!), title: Text('Is Break?'))])), actions: [ElevatedButton(onPressed: (){ var t=Timetable(id: edit?.id??DateTime.now().millisecondsSinceEpoch.toString(), day:day.text, period:period.text, cls:cls.text, stream:stream.text, subject:sub.text, teacher:teacher.text, time:time.text, isBreak:isBreak); widget.onSync(t); Navigator.pop(x); }, child: Text('Save LIVE'))])));
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar: AppBar(title: Text('Timetable LIVE'),backgroundColor: Color(0xFF0D47A1)), floatingActionButton: widget.readOnly?null:FloatingActionButton(child: Icon(Icons.add),backgroundColor: Color(0xFF0D47A1), onPressed: ()=>addEdit()), body: ListView.builder(padding: EdgeInsets.all(12), itemCount: widget.timetable.length, itemBuilder: (c,i){ var t=widget.timetable[i]; return Card(color: t.isBreak?Colors.orange[50]:null, child: ListTile(title: Text('${t.day} ${t.period} ${t.time} ${t.subject}'), subtitle: Text('${t.cls} ${t.stream} ${t.teacher} LIVE'), trailing: widget.readOnly?null:Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.edit,color: Colors.blue), onPressed: ()=>addEdit(edit:t)), IconButton(icon: Icon(Icons.delete,color: Colors.red), onPressed: ()=>widget.db.collection('timetable').doc(t.id).delete())]))); }));
}

class ReportsPage extends StatefulWidget { final List<Student> studs; final List<AttendanceLog> logs; ReportsPage({required this.studs, required this.logs}); @override _ReportsPageState createState()=>_ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage> {
  String selClass='S.4'; String selStream='All';
  List<String> classes=['S.1','S.2','S.3','S.4','S.5','S.6'];
  List<String> get streams => selClass=='S.5'||selClass=='S.6'? ['All','Sciences','Arts'] : ['All','Blue','Red','Green'];
  List<Map<String,dynamic>> get mostAbsent {
    var filtered=widget.studs.where((s){ if(s.cls!=selClass) return false; if(selStream!='All'&&s.stream!=selStream) return false; return true; }).toList();
    List<Map<String,dynamic>> data=filtered.map((s){ int absent=widget.logs.where((l)=>l.idNo==s.idNo&&l.status!='PRESENT').length; int present=widget.logs.where((l)=>l.idNo==s.idNo&&l.status=='PRESENT').length; return {'student':s,'absent':absent,'present':present}; }).toList();
    data.sort((a,b)=>(b['absent'] as int).compareTo(a['absent'] as int));
    return data;
  }
  Future<void> exportPdf() async {
    final pdf=pw.Document();
    pdf.addPage(pw.Page(build: (c)=>pw.Column(children: [pw.Text('BSS GoB - Most Absent LIVE - $selClass $selStream', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height:10), pw.Table.fromTextArray(headers: ['Name','ID','Class','Stream','Present','Absent'], data: mostAbsent.map((m){ var s=m['student'] as Student; return [s.name,s.idNo,s.cls,s.stream,m['present'].toString(),m['absent'].toString()]; }).toList())])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }
  @override Widget build(BuildContext c){
    var data=mostAbsent;
    return Scaffold(appBar: AppBar(title: Text('Reports LIVE CAM'), backgroundColor: Color(0xFF0D47A1)), floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.red, icon: Icon(Icons.picture_as_pdf), label: Text('Export PDF LIVE'), onPressed: exportPdf), body: Column(children: [Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: DropdownButton<String>(value: selClass,isExpanded:true,items: classes.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>setState(()=>selClass=v!))), SizedBox(width:6), Expanded(child: DropdownButton<String>(value: selStream,isExpanded:true,items: streams.map((e)=>DropdownMenuItem(value:e,child:Text('Stream: $e'))).toList(), onChanged: (v)=>setState(()=>selStream=v!))),])), Expanded(child: ListView.builder(itemCount: data.length, itemBuilder: (c,i){ var m=data[i]; var s=m['student'] as Student; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: m['absent']>2?Colors.red:Colors.orange, child: Text('${m['absent']}',style: TextStyle(color: Colors.white))), title: Text(s.name), subtitle: Text('${s.idNo} | ${s.cls} ${s.stream} | P:${m['present']} A:${m['absent']} LIVE'))); }))]));
  }
}

class Setup extends StatefulWidget { final List<Student> studs; final Function(int,int) onGrantSingle; final Function(List<int>,int) onGrantMulti; Setup({required this.studs, required this.onGrantSingle, required this.onGrantMulti}); @override _SetupState createState()=>_SetupState(); }
class _SetupState extends State<Setup> {
  List<int> selected=[]; DateTime from=DateTime.now(); DateTime to=DateTime.now().add(Duration(days:7));
  int get daysCount => to.difference(from).inDays+1;
  List<Student> get defaulters => widget.studs.where((s)=>s.zones.values.any((z)=>z.expired)).toList();
  @override Widget build(BuildContext c){
    return Scaffold(appBar: AppBar(title: Text('Setup LIVE'),backgroundColor: Color(0xFF0D47A1)), body: Column(children: [
      Card(color: Colors.green[50], margin: EdgeInsets.all(8), child: Padding(padding: EdgeInsets.all(12), child: Column(children: [
        Text('Grant LIVE From..To..',style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [Expanded(child: ElevatedButton(onPressed: () async { var d=await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2025), lastDate: DateTime(2028)); if(d!=null) setState(()=>from=d); }, child: Text('From ${from.toString().split(' ')[0]}'))), SizedBox(width:6), Expanded(child: ElevatedButton(onPressed: () async { var d=await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2025), lastDate: DateTime(2028)); if(d!=null) setState(()=>to=d); }, child: Text('To ${to.toString().split(' ')[0]}'))),]),
        Text('Days: $daysCount LIVE SYNC',style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [ElevatedButton(onPressed: ()=>setState(()=>selected=List.generate(defaulters.length, (i)=>widget.studs.indexOf(defaulters[i]))), child: Text('Select All')), SizedBox(width:6), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: selected.isEmpty?null:(){ widget.onGrantMulti(selected,daysCount); setState(()=>selected=[]); }, child: Text('Grant ${selected.length} LIVE'))]),
      ]))),
      Expanded(child: ListView.builder(itemCount: defaulters.length, itemBuilder: (c,i){ var s=defaulters[i]; int real=widget.studs.indexOf(s); bool isSel=selected.contains(real); return Card(child: CheckboxListTile(value: isSel, onChanged: (v){ setState((){ if(v==true) selected.add(real); else selected.remove(real); }); }, title: Text(s.name), subtitle: Text('${s.cls} ${s.stream} GATE ${s.zones['GATE']!.left}d LIVE'), secondary: PopupMenuButton<String>(onSelected: (v){ int d=v=='day'?1:v=='week'?7:v=='month'?30:365; widget.onGrantSingle(real,d); }, itemBuilder: (c)=>[PopupMenuItem(value:'day',child: Text('Grant 1 Day LIVE')), PopupMenuItem(value:'week',child: Text('Grant Week LIVE')), PopupMenuItem(value:'month',child: Text('Grant Month LIVE'))]))); }))
    ]));
  }
}