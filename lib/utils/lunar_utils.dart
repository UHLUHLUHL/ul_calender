import 'package:lunar/lunar.dart';

class LunarUtils {
  static String getLunarDate(DateTime date) {
    try {
      Solar solar = Solar.fromYmd(date.year, date.month, date.day);
      Lunar lunar = solar.getLunar();
      return "${lunar.getMonth()}월 ${lunar.getDay()}일";
    } catch (e) {
      return "0월 0일";
    }
  }

  static bool isHoliday(DateTime date) {
    // 양력 고정 공휴일
    final month = date.month;
    final day = date.day;
    if (month == 1 && day == 1) return true;
    if (month == 3 && day == 1) return true;
    if (month == 5 && day == 5) return true;
    if (month == 6 && day == 6) return true;
    if (month == 8 && day == 15) return true;
    if (month == 10 && day == 3) return true;
    if (month == 10 && day == 9) return true;
    if (month == 12 && day == 25) return true;

    // 2026년 특정 대체 공휴일 (예: 3월 2일 등)
    if (date.year == 2026) {
      if (month == 3 && day == 2) return true; // 삼일절 대체
      if (month == 2 && day == 10) return true; // 설날 대체 (있을 경우)
      if (month == 5 && day == 4) return true; // 어린이날 대체 (만약 주말 겹칠 시)
      if (month == 10 && day == 5) return true; // 추석 대체 (만약 주말 겹칠 시)
    }

    // 음력 공휴일 판정 (설날, 추석)
    Solar solar = Solar.fromYmd(date.year, date.month, date.day);
    Lunar lunar = solar.getLunar();
    int lm = lunar.getMonth();
    int ld = lunar.getDay();

    // 설날 연휴 (음력 12.말, 1.1, 1.2) - 편의상 1.1 전후일
    if (lm == 1 && (ld == 1 || ld == 2)) return true;
    // 음력 12월의 마지막 날인지 확인 (설 전날)
    Solar prevSolar = Solar.fromYmd(
      date.subtract(const Duration(days: 1)).year,
      date.subtract(const Duration(days: 1)).month,
      date.subtract(const Duration(days: 1)).day,
    );
    Lunar prevLunar = prevSolar.getLunar();
    if (prevLunar.getMonth() == 1 && prevLunar.getDay() == 1)
      return true; // ld가 설 전날일 때 처리

    // 추석 연휴 (음력 8.14, 8.15, 8.16)
    if (lm == 8 && (ld == 14 || ld == 15 || ld == 16)) return true;

    return false;
  }

  static String? getHolidayName(DateTime date) {
    final month = date.month;
    final day = date.day;
    if (month == 1 && day == 1) return '신정';
    if (month == 3 && day == 1) return '삼일절';
    if (month == 5 && day == 5) return '어린이날';
    if (month == 6 && day == 6) return '현충일';
    if (month == 8 && day == 15) return '광복절';
    if (month == 10 && day == 3) return '개천절';
    if (month == 10 && day == 9) return '한글날';
    if (month == 12 && day == 25) return '성탄절';

    // 2026 대체 공휴일
    if (date.year == 2026) {
      if (month == 3 && day == 2) return '대체공휴일(삼일절)';
    }

    // 음력 공휴일 (설날, 추석)
    Solar solar = Solar.fromYmd(date.year, date.month, date.day);
    Lunar lunar = solar.getLunar();
    int lm = lunar.getMonth();
    int ld = lunar.getDay();

    if (lm == 1 && ld == 1) return '설날';
    if (lm == 1 && ld == 2) return '설 연휴';
    Solar nextSolar = Solar.fromYmd(
      date.add(const Duration(days: 1)).year,
      date.add(const Duration(days: 1)).month,
      date.add(const Duration(days: 1)).day,
    );
    Lunar nextLunar = nextSolar.getLunar();
    if (nextLunar.getMonth() == 1 && nextLunar.getDay() == 1) return '설 연휴';

    if (lm == 8 && ld == 15) return '추석';
    if (lm == 8 && (ld == 14 || ld == 16)) return '추석 연휴';

    return null;
  }
}
