import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child.dart';
import '../models/institution.dart';
import '../models/schedule.dart';

class FirestoreService {
  final String? uid;

  FirestoreService({this.uid});

  // 유저 컬렉션 참조
  CollectionReference get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  // 자녀 컬렉션 참조
  CollectionReference<Child> get _childrenCollection =>
      _usersCollection.doc(uid).collection('children').withConverter<Child>(
        fromFirestore: (snapshots, _) => Child.fromFirestore(snapshots),
        toFirestore: (child, _) => child.toFirestore(),
      );

  // 기관 컬렉션 참조
  CollectionReference<Institution> get _institutionsCollection =>
      _usersCollection.doc(uid).collection('institutions').withConverter<Institution>(
        fromFirestore: (snapshots, _) => Institution.fromFirestore(snapshots),
        toFirestore: (institution, _) => institution.toFirestore(),
      );

  // 스케줄 컬렉션 참조
  CollectionReference<Schedule> get _schedulesCollection =>
      _usersCollection.doc(uid).collection('schedules').withConverter<Schedule>(
        fromFirestore: (snapshots, _) => Schedule.fromFirestore(snapshots),
        toFirestore: (schedule, _) => schedule.toFirestore(),
      );

  // --- 자녀 (Child) CRUD ---

  // 자녀 목록 실시간 스트림
  Stream<List<Child>> getChildren() {
    if (uid == null) return Stream.value([]);
    return _childrenCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // 자녀 추가
  Future<void> addChild(Child child) async {
    if (uid == null) return;
    await _childrenCollection.add(child);
  }

  // 자녀 수정
  Future<void> updateChild(Child child) async {
    if (uid == null) return;
    await _childrenCollection.doc(child.id).update(child.toFirestore());
  }

  // 자녀 삭제
  Future<void> deleteChild(String childId) async {
    if (uid == null) return;
    await _childrenCollection.doc(childId).delete();
  }

  // --- 기관 (Institution) CRUD ---

  // 기관 목록 실시간 스트림
  Stream<List<Institution>> getInstitutions() {
    if (uid == null) return Stream.value([]);
    return _institutionsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // 기관 추가
  Future<void> addInstitution(Institution institution) async {
    if (uid == null) return;
    await _institutionsCollection.add(institution);
  }

  // 기관 수정
  Future<void> updateInstitution(Institution institution) async {
    if (uid == null) return;
    await _institutionsCollection.doc(institution.id).update(institution.toFirestore());
  }

  // 기관 삭제
  Future<void> deleteInstitution(String institutionId) async {
    if (uid == null) return;
    await _institutionsCollection.doc(institutionId).delete();
  }

  // --- 스케줄 (Schedule) CRUD ---

  // 스케줄 목록 실시간 스트림
  Stream<List<Schedule>> getSchedules() {
    if (uid == null) return Stream.value([]);
    // 참고: orderBy를 사용하려면 Firestore 콘솔에서 색인을 생성해야 할 수 있습니다.
    // 여기서는 클라이언트 측에서 정렬합니다.
    return _schedulesCollection.snapshots().map((snapshot) {
      var schedules = snapshot.docs.map((doc) => doc.data()).toList();
      // 시간순 정렬 (예시)
      schedules.sort((a, b) => a.time.compareTo(b.time));
      return schedules;
    });
  }

  // 스케줄 추가
  Future<DocumentReference<Schedule>> addSchedule(Schedule schedule) async {
    if (uid == null) throw Exception("User not logged in");
    return await _schedulesCollection.add(schedule);
  }

  // 스케줄 수정
  Future<void> updateSchedule(Schedule schedule) async {
    if (uid == null) return;
    await _schedulesCollection.doc(schedule.id).update(schedule.toFirestore());
  }

  // 스케줄 삭제
  Future<void> deleteSchedule(String scheduleId) async {
    if (uid == null) return;
    await _schedulesCollection.doc(scheduleId).delete();
  }
}
