import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

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

      // Firebase에 로그인 및 User 객체 반환
      // 루틴 관리 앱의 경우 아래와 같이 로그인 진행.
      // final userCredential = await _auth.signInWithCredential(credential);
      // return userCredential.user;

      // 4. Firebase에 로그인
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;
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
}
