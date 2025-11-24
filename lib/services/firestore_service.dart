import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config.dart';
import '../models/child.dart';
import '../models/institution.dart';
import '../models/schedule.dart';
import '../utils/logger.dart';

class FirestoreService {
  final String? uid;
  FirestoreService({this.uid});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 앱 설정(버전, 공지사항 등) 가져오기
  // 'app_config' 컬렉션의 'common' 문서 하나를 사용한다고 가정합니다.
  Future<AppConfig> getAppConfig() async {
    try {
      final doc = await _db.collection('app_config').doc('common').get();
      if (doc.exists) {
        return AppConfig.fromFirestore(doc);
      }
      // 문서가 없으면 기본값 반환
      return AppConfig(latestVersion: '1.0.0', minVersion: '1.0.0');
    } catch (e) {
      logger.e('AppConfig 로드 실패: $e');
      return AppConfig(latestVersion: '1.0.0', minVersion: '1.0.0');
    }
  }

  // --- Helper for Deletion ---
  // 컬렉션 내의 모든 문서를 삭제하는 헬퍼 함수
  Future<void> _deleteCollection(CollectionReference collectionRef) async {
    final QuerySnapshot snapshot = await collectionRef.get();
    // [중요] 문서가 많은 경우를 대비해 WriteBatch 사용
    final WriteBatch batch = _db.batch();
    for (DocumentSnapshot doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // 계정 탈퇴 시 모든 사용자 데이터 삭제
  Future<void> deleteAllUserData() async {
    if (uid == null) {
      logger.e('데이터 삭제 불가: UID가 null입니다.');
      return;
    }
    logger.w('사용자($uid)의 모든 Firestore 데이터를 삭제합니다...');

    // 삭제할 모든 하위 컬렉션 참조
    final schedulesRef = _db.collection('users').doc(uid).collection('schedules');
    final childrenRef = _db.collection('users').doc(uid).collection('children');
    final institutionsRef = _db.collection('users').doc(uid).collection('institutions');

    try {
      // 모든 컬렉션의 문서 삭제를 병렬로 실행
      await Future.wait([
        _deleteCollection(schedulesRef),
        _deleteCollection(childrenRef),
        _deleteCollection(institutionsRef),
      ]);
      logger.i('사용자($uid)의 모든 Firestore 데이터 삭제 완료.');
    } catch (e) {
      logger.e('Firestore 데이터 삭제 중 오류 발생: $e');
      // 오류가 발생해도 계정 삭제는 계속 진행해야 할 수 있으므로 rethrow하지 않음
    }
  }

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
    if (uid == null) throw Exception('User not logged in');

    final WriteBatch batch = _db.batch();

    // 1. 'children' 컬렉션의 자녀 정보 업데이트
    final childRef = _db.collection('users').doc(uid).collection('children').doc(child.id);
    batch.update(childRef, child.toFirestore());

    // 2. 'schedules' 컬렉션에서 이 자녀 ID를 가진 모든 일정 쿼리
    final schedulesRef = _db.collection('users').doc(uid).collection('schedules');
    final querySnapshot = await schedulesRef.where('childId', isEqualTo: child.id).get();

    // 3. 쿼리 결과(모든 관련 일정)의 'childName'을 새 이름으로 업데이트
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'childName': child.name});
    }

    // 4. 모든 작업을 하나의 트랜잭션으로 실행
    await batch.commit();

    // await _childrenCollection.doc(child.id).update(child.toFirestore());
  }

  // 자녀 삭제 시, 관련된 모든 일정(Schedule)도 함께 삭제
  Future<void> deleteChild(String childId) async {
    if (uid == null) throw Exception('User not logged in');

    final WriteBatch batch = _db.batch();

    // 1. 'children' 컬렉션의 자녀 정보 삭제
    final childRef = _db.collection('users').doc(uid).collection('children').doc(childId);
    batch.delete(childRef);

    // 2. 'schedules' 컬렉션에서 이 자녀 ID를 가진 모든 일정 쿼리
    final schedulesRef = _db.collection('users').doc(uid).collection('schedules');
    final querySnapshot = await schedulesRef.where('childId', isEqualTo: childId).get();

    // 3. 쿼리 결과(모든 관련 일정)를 삭제
    // (참고: 이로 인해 예약된 알림은 삭제되지 않습니다.
    //   계정 탈퇴 시의 cancelAllNotifications() 또는 앱 재설치 시 해결됩니다.)
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 4. 모든 작업을 하나의 트랜잭션으로 실행
    await batch.commit();

    // await _childrenCollection.doc(childId).delete();
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

  // 기관 이름/정보 변경 시, 관련된 모든 일정(Schedule)의 'institutionName'도 함께 업데이트
  Future<void> updateInstitution(Institution institution) async {
    if (uid == null) throw Exception('User not logged in');

    // await _institutionsCollection.doc(institution.id).update(institution.toFirestore());

    final WriteBatch batch = _db.batch();

    // 1. 'institutions' 컬렉션의 기관 정보 업데이트
    final instRef = _db.collection('users').doc(uid).collection('institutions').doc(institution.id);
    batch.update(instRef, institution.toFirestore());

    // 2. 'schedules' 컬렉션에서 이 기관 ID를 가진 모든 일정 쿼리
    final schedulesRef = _db.collection('users').doc(uid).collection('schedules');
    final querySnapshot = await schedulesRef.where('institutionId', isEqualTo: institution.id).get();

    // 3. 쿼리 결과(모든 관련 일정)의 'institutionName'을 새 이름으로 업데이트
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'institutionName': institution.name});
    }

    // 4. 모든 작업을 하나의 트랜잭션으로 실행
    await batch.commit();
  }

  // 기관 삭제 시, 관련된 모든 일정(Schedule)도 함께 삭제
  Future<void> deleteInstitution(String institutionId) async {
    if (uid == null) throw Exception('User not logged in');

    // await _institutionsCollection.doc(institutionId).delete();

    final WriteBatch batch = _db.batch();

    // 1. 'institutions' 컬렉션의 기관 정보 삭제
    final instRef = _db.collection('users').doc(uid).collection('institutions').doc(institutionId);
    batch.delete(instRef);

    // 2. 'schedules' 컬렉션에서 이 기관 ID를 가진 모든 일정 쿼리
    final schedulesRef = _db.collection('users').doc(uid).collection('schedules');
    final querySnapshot = await schedulesRef.where('institutionId', isEqualTo: institutionId).get();

    // 3. 쿼리 결과(모든 관련 일정)를 삭제
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 4. 모든 작업을 하나의 트랜잭션으로 실행
    await batch.commit();
  }

  // --- 스케줄 (Schedule) CRUD ---
  // 스케줄 목록 실시간 스트림
  Stream<List<Schedule>> getSchedules() {
    if (uid == null) return Stream.value([]);
    // 참고: orderBy를 사용하려면 Firestore 콘솔에서 색인을 생성해야 할 수 있습니다.
    // 여기서는 클라이언트 측에서 정렬합니다.
    return _schedulesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
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

  // 동기화를 위해 Ref를 반환하는 메서드들
  Future<DocumentReference> addReturnRefChild(String name) {
    if (uid == null) throw Exception('User not logged in');
    final ref = _db.collection('users').doc(uid).collection('children');
    return ref.add({'name': name});
  }

  Future<DocumentReference> addReturnRefInstitution(String name, String contactNumber) {
    if (uid == null) throw Exception('User not logged in');
    final ref = _db.collection('users').doc(uid).collection('institutions');
    return ref.add({'name': name, 'contactNumber': contactNumber});
  }
}
