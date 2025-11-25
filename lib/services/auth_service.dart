import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../utils/logger.dart';
import 'data_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final DataRepository _dataRepository = DataRepository(); // Repository 인스턴스

  // AppUser 모델로 변환
  AppUser? _userFromFirebaseUser(User? user) {
    return user != null ? AppUser(uid: user.uid) : null;
  }

  // 유저 변경 스트림
  Stream<AppUser?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }

  // Google 로그인
  Future<AppUser?> signInWithGoogle() async {
    try {
      // 1. Google 로그인 UI 표시 및 사용자 선택
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        // 사용자가 로그인을 취소함
        return null;
      }

      // 1. idToken을 가져옵니다. (await 제거)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // 2. accessToken을 authorizationClient를 통해 가져옵니다.
      //    'email' 스코프는 Firebase 인증에 필요할 수 있습니다.
      final GoogleSignInClientAuthorization authClient =
      await googleUser.authorizationClient.authorizeScopes(['email']);
      final String accessToken = authClient.accessToken;

      // 3. 토큰 유효성 검사
      if (idToken == null) {
        logger.e("Google idToken is null.");
        return null;
      }

      // 새로운 토큰 값으로 credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // 4. Firebase에 로그인
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      // [추가] 로그인 성공 후 데이터 동기화 시도
      if (user != null) {
        logger.i('로그인 성공. 로컬 데이터 동기화 시작...');
        await _dataRepository.syncLocalDataToFirestore(user.uid);
        logger.i('동기화 완료.');
      }

      return _userFromFirebaseUser(user);

    } catch (e) {
      logger.e(e.toString());
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Google 로그아웃
      await _auth.signOut(); // Firebase 로그아웃
    } catch (e) {
      logger.e(e.toString());
      return;
    }
  }

  // 계정 탈퇴 (모든 데이터 삭제 후 호출)
  Future<bool> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      logger.w('삭제할 사용자가 없습니다.');
      return false;
    }

    try {
      // [중요] 계정 삭제는 민감한 작업이므로, Google 재인증을 먼저 수행합니다.
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        logger.i('계정 삭제를 위한 재인증이 취소되었습니다.');
        return false; // 사용자가 재인증 취소
      }

      // 1. idToken을 가져옵니다. (await 제거)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // 2. accessToken을 authorizationClient를 통해 가져옵니다.
      //    'email' 스코프는 Firebase 인증에 필요할 수 있습니다.
      final GoogleSignInClientAuthorization authClient = await googleUser.authorizationClient.authorizeScopes(['email']);
      final String accessToken = authClient.accessToken;

      if (idToken == null) {
        logger.e('재인증 토큰 가져오기 실패');
        return false;
      }

      // 새로운 토큰 값으로 credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // 현재 사용자를 Firebase에 재인증
      await user.reauthenticateWithCredential(credential);

      // 재인증 성공 시, 계정 삭제
      await user.delete();

      logger.i('Firebase Auth 계정 삭제 성공.');

      // Google에서도 로그아웃
      await _googleSignIn.signOut();
      await _auth.signOut();

      return true;
    } catch (e) {
      // 사용자 취소인 경우 (PlatformException code check 등 가능하지만 단순화)
      logger.e('계정 삭제 실패: $e');
      // 상위로 에러를 던져서 스낵바를 띄울지 결정하게 함
      // 단, 재인증 취소는 위에서 false로 리턴했으므로 여기는 진짜 에러임
      rethrow;
    }
  }
}
