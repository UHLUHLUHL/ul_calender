import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'providers/calendar_provider.dart';
import 'views/main_calendar_screen.dart';
import 'views/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ko_KR', null);

  runApp(
    // Provider를 최상위에 배치하여 모든 화면에서 접근 가능하게 함
    ChangeNotifierProvider(
      create: (_) => CalendarProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '울 캘린더',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const AuthWrapper(),
    );
  }
}

// 로그인 상태에 따라 화면 분기
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인 상태 확인
        if (snapshot.hasData && snapshot.data != null) {
          // 로그인됨 -> 캘린더 화면 표시
          return const MainCalendarScreen();
        } else {
          // 미로그인 -> 로그인 화면 표시
          return const LoginScreen();
        }
      },
    );
  }
}
