import 'package:cloud_firestore/cloud_firestore.dart';

// SINGLE SOURCE OF TRUTH FOR TIMETABLE
class Timetable {
  String id; String day, period, cls, stream, subject, teacher, time; bool isBreak;
  String? group; // For multi-subjects in same period e.g Group A / Commerce Group
  Timetable({required this.id, required this.day, required this.period, required this.cls, required this.stream, required this.subject, required this.teacher, required this.time, this.isBreak=false, this.group});
  Map<String,dynamic> toMap()=>{'id':id,'day':day,'period':period,'cls':cls,'stream':stream,'subject':subject,'teacher':teacher,'time':time,'isBreak':isBreak, 'group':group??''};
  static Timetable fromMap(Map m)=>Timetable(id:m['id']??'',day:m['day']??'',period:m['period']??'',cls:m['cls']??'',stream:m['stream']??'',subject:m['subject']??'',teacher:m['teacher']??'',time:m['time']??'',isBreak:m['isBreak']??false, group:m['group']??'');
}

class PeriodConfig {
  String p; String t;
  PeriodConfig({required this.p, required this.t});
  Map<String,dynamic> toMap()=> {'p':p,'t':t};
  static PeriodConfig fromMap(Map m)=> PeriodConfig(p:m['p']??'P1', t:m['t']??'08:00-08:40');
}