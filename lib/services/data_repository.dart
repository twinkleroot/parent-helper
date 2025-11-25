// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart'; // Stream 병합용 (선택 사항이지만 유용함)
import '../models/child.dart';
import '../models/institution.dart';
import '../models/schedule.dart';
import '../models/app_config.dart';
import '../models/user.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';

class DataRepository {
  FirestoreService _firestoreService;
  final LocalDatabaseService _localDb;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로컬 데이터 변경사항을 즉시 반영하기 위한 Subject
  // 초기값으로 빈 리스트를 넣어둡니다.
  final BehaviorSubject<List<Schedule>> _localSchedulesSubject = BehaviorSubject<List<Schedule>>.seeded([]);
  final BehaviorSubject<List<Child>> _localChildrenSubject = BehaviorSubject<List<Child>>.seeded([]);
  final BehaviorSubject<List<Institution>> _localInstitutionsSubject = BehaviorSubject<List<Institution>>.seeded([]);

  DataRepository()
      : _firestoreService = FirestoreService(uid: FirebaseAuth.instance.currentUser?.uid),
        _localDb = LocalDatabaseService() {
    // 초기 로컬 데이터 로드
    _refreshLocalData();
  }

  // 현재 로그인 여부 확인
  bool get isLogged => _auth.currentUser != null;

  // FirestoreService 인스턴스 업데이트 (로그인/로그아웃 시 호출)
  void updateAuth(AppUser? user) {
    _firestoreService = FirestoreService(uid: user?.uid);
    // 로그인 상태가 바뀌면 로컬 데이터도 다시 한번 리프레시 (비로그인 전환 시 필요)
    if (user == null) {
      _refreshLocalData();
    }
  }

  // 로컬 데이터 새로고침 (CRUD 후 호출)
  Future<void> _refreshLocalData() async {
    _localSchedulesSubject.add(await _localDb.getAllSchedules());
    _localChildrenSubject.add(await _localDb.getChildren());
    _localInstitutionsSubject.add(await _localDb.getInstitutions());
  }

  // --- AppConfig (항상 Firestore에서 가져옴 - 공지사항 등) ---
  Future<AppConfig> getAppConfig() async {
    // 공지사항은 비로그인이어도 서버에서 가져와야 함
    // FirestoreService에 uid가 없어도 읽을 수 있는 public 컬렉션이라면 가능
    return await FirestoreService(uid: null).getAppConfig();
  }

  // --- CRUD Methods (스위칭 로직) ---

  Stream<List<Schedule>> getAllSchedules() {
    if (isLogged) {
      return _firestoreService.getSchedules();
    } else {
      // 로컬일 때는 BehaviorSubject를 반환하여 실시간성을 확보
      return _localSchedulesSubject.stream;
    }
  }

  // StreamBuilder에서 실시간 갱신을 위해, 로컬 DB 사용시에는
  // 데이터 변경 후 UI를 갱신하는 트리거가 필요합니다.
  // 여기서는 간단히 'Future -> Stream' 변환만 제공하고,
  // UI에서는 setState로 다시 빌드되도록 유도하겠습니다.

  Future<String> addSchedule(Schedule schedule) async {
    if (isLogged) {
      final ref = await FirestoreService(uid: _auth.currentUser!.uid).addSchedule(schedule);
      return ref.id;
    } else {
      final id = await _localDb.addSchedule(schedule);
      _refreshLocalData(); // [추가] 데이터 갱신
      return id;
    }
  }

  Future<void> updateSchedule(Schedule schedule) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).updateSchedule(schedule);
    } else {
      await _localDb.updateSchedule(schedule);
      _refreshLocalData(); // [추가]
    }
  }

  Future<void> deleteSchedule(String id) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).deleteSchedule(id);
    } else {
      await _localDb.deleteSchedule(id);
      _refreshLocalData(); // [추가]
    }
  }

  // --- Children ---
  Stream<List<Child>> getChildren() {
    if (isLogged) {
      return FirestoreService(uid: _auth.currentUser!.uid).getChildren();
    } else {
      return _localChildrenSubject.stream;
    }
  }

  Future<void> addChild(String name) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).addChild(Child(id: '', name: name));
    } else {
      await _localDb.addChild(name);
      _refreshLocalData();
    }
  }

  Future<void> updateChild(Child child) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).updateChild(child);
    } else {
      await _localDb.updateChild(child);
      _refreshLocalData();
    }
  }

  Future<void> deleteChild(String id) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).deleteChild(id);
    } else {
      await _localDb.deleteChild(id);
      _refreshLocalData();
    }
  }

  // --- Institutions ---
  Stream<List<Institution>> getInstitutions() {
    if (isLogged) {
      return FirestoreService(uid: _auth.currentUser!.uid).getInstitutions();
    } else {
      return _localInstitutionsSubject.stream;
    }
  }

  Future<void> addInstitution(String name, String contact, {String memo = ''}) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).addInstitution(Institution(id: '', name: name, contactNumber: contact, memo: memo));
    } else {
      await _localDb.addInstitution(name, contact, memo);
      _refreshLocalData();
    }
  }

  Future<void> updateInstitution(Institution inst) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).updateInstitution(inst);
    } else {
      await _localDb.updateInstitution(inst);
      _refreshLocalData();
    }
  }

  Future<void> deleteInstitution(String id) async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).deleteInstitution(id);
    } else {
      await _localDb.deleteInstitution(id);
      _refreshLocalData();
    }
  }

  // [!!] 데이터 동기화 (로컬 -> 파이어스토어)
  Future<void> syncLocalDataToFirestore(String uid) async {
    final firestore = FirestoreService(uid: uid);

    // 1. 로컬 데이터 모두 가져오기
    final localChildren = await _localDb.getChildren();
    final localInsts = await _localDb.getInstitutions();
    final localSchedules = await _localDb.getAllSchedules();

    // 2. Firestore에 업로드 (Batch 처리 권장하지만 여기선 반복문으로 단순화)
    // ID를 유지하면서 업로드할지, 새로 생성할지 결정해야 함.
    // Firestore는 ID 자동생성이므로, 로컬 ID를 무시하고 새로 생성하는게 충돌 방지에 좋음.
    // 하지만 관계(Schedule -> Child)를 유지해야 하므로,
    // 로컬 ID -> 서버 ID 매핑이 필요함.

    Map<String, String> childIdMap = {};
    Map<String, String> instIdMap = {};

    // 자녀 업로드
    for (var child in localChildren) {
      final ref = await firestore.addReturnRefChild(child.name); // FirestoreService에 addReturnRefChild 필요
      childIdMap[child.id] = ref.id;
    }

    // 기관 업로드
    for (var inst in localInsts) {
      final ref = await firestore.addReturnRefInstitution(inst.name, inst.contactNumber, inst.memo);
      instIdMap[inst.id] = ref.id;
    }

    // 스케줄 업로드 (매핑된 ID 사용)
    for (var sch in localSchedules) {
      final newChildId = childIdMap[sch.childId];
      final newInstId = instIdMap[sch.institutionId];

      if (newChildId != null && newInstId != null) {
        final newSchedule = Schedule(
          id: '', // Firestore가 생성
          childId: newChildId,
          childName: sch.childName,
          institutionId: newInstId,
          institutionName: sch.institutionName,
          type: sch.type,
          daysOfWeek: sch.daysOfWeek,
          time: sch.time,
          notificationLeadTimeInMinutes: sch.notificationLeadTimeInMinutes,
          isEnabled: sch.isEnabled,
          memo: sch.memo,
        );
        await firestore.addSchedule(newSchedule);
      }
    }

    // [수정] 연동 후 로컬 데이터를 삭제하지 않고 유지합니다. -> 주석처리
    // 3. 로컬 데이터 삭제
    // await _localDb.clearAllData();
    // _refreshLocalData();
  }

  Future<void> deleteAllUserData() async {
    if (isLogged) {
      await FirestoreService(uid: _auth.currentUser!.uid).deleteAllUserData();
    } else {
      await _localDb.clearAllData();
      _refreshLocalData();
    }
  }
}