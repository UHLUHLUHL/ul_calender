import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      // 강제로 계정 선택창을 띄우기 위해 이전 세션 종료
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // 로그인 취소

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect(); // 연결 해제 (계정 선택창 다시 띄우기 위함)
    } catch (e) {
      // 이미 해제되었거나 로그인되지 않은 경우 무시
      print('Disconnect error: $e');
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
