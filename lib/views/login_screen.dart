import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final user = await _authService.signInWithGoogle();

    setState(() => _isLoading = false);

    if (user == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 취소되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앱 아이콘 (Premium Design)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF339AF0), Color(0xFF1971C2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 앱 이름
                const Text(
                  '울 캘린더',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ul Calender',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '모든 기기에서 일정을 동기화하세요',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 64),

                // 구글 브랜드 가이드라인 준수 버튼 (Pill shape and design update)
                _isLoading
                    ? const CircularProgressIndicator()
                    : InkWell(
                        onTap: _handleGoogleSignIn,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 280,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 14),
                              // 구글 로고 (PNG 버전 사용)
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                width: 22,
                                height: 22,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.g_mobiledata,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: 36.0,
                                    ), // 로고 너비만큼 보정
                                    child: Text(
                                      'Sign in with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(
                                          0xFF3C4043,
                                        ), // Google standard text color
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 24),

                // Info text
                Text(
                  '로그인하면 일정이 클라우드에 저장되어\n기기를 바꿔도 복원됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
