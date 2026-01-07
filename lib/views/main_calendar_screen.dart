import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/calendar_provider.dart';
import '../models/schedule_model.dart';
import '../models/income_model.dart';
import '../utils/lunar_utils.dart';
import 'package:device_calendar/device_calendar.dart';

import 'unified_entry_dialog.dart';
import 'profile_edit_dialog.dart';
import 'search_dialog.dart';

class MainCalendarScreen extends StatefulWidget {
  const MainCalendarScreen({super.key});

  @override
  State<MainCalendarScreen> createState() => _MainCalendarScreenState();
}

class _MainCalendarScreenState extends State<MainCalendarScreen> {
  static const Color kSelectionGrey = Color(0xFFD0D0D0);
  static const Color kPopupBg = Color(0xFFF5F7FA);

  int _drawerPage = 0;

  String _formatManWon(double amount) {
    if (amount == 0) return "0";
    double value = amount / 10000;
    if (value % 1 == 0) return "${value.toInt()}만";
    return "${value.toStringAsFixed(1)}만";
  }

  List<Event> _getDeviceEventsForDay(CalendarProvider provider, DateTime date) {
    return provider.monthlyDeviceEvents.where((e) {
      if (e.start == null) return false;
      return e.start!.year == date.year &&
          e.start!.month == date.month &&
          e.start!.day == date.day;
    }).toList();
  }

  // 현재 로그인된 사용자 이메일 가져오기
  String? _getCurrentUserEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  // 로그아웃 처리
  Future<void> _handleLogout() async {
    Navigator.pop(context); // Drawer 닫기
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CalendarProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(provider),
      drawer: _buildIntegratedDrawer(provider),
      body: Column(
        children: [
          GestureDetector(
            onTap: () => _showProfileBreakdownPopup(provider),
            child: _buildIncomeHeader(provider),
          ),

          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: provider.focusedDate,
            selectedDayPredicate: (day) =>
                isSameDay(provider.selectedDate, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: provider.onDateSelected,
            onPageChanged: provider.onPageChanged,
            headerVisible: false,
            rowHeight: 62,
            daysOfWeekHeight: 28,

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, date, _) =>
                  _buildDayCell(provider, date, false),
              selectedBuilder: (ctx, date, _) =>
                  _buildDayCell(provider, date, true),
              todayBuilder: (ctx, date, focused) =>
                  _buildDayCell(provider, date, false, isToday: true),
              outsideBuilder: (ctx, date, focused) =>
                  _buildDayCell(provider, date, false, isOutside: true),
              markerBuilder: (ctx, date, events) => _buildMarker(ctx, date),
            ),

            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Color(0xFF888888),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              weekendStyle: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: kPopupBg,
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "${provider.selectedDate.day}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'EEEE',
                                  'ko_KR',
                                ).format(provider.selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "음력 ${LunarUtils.getLunarDate(provider.selectedDate)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          if (provider.dailyIncomes.isNotEmpty)
                            _buildStandaloneIncomeIndicator(provider),
                        ],
                      ),

                      // Device Events (Holidays) List
                      ..._getDeviceEventsForDay(
                        provider,
                        provider.selectedDate,
                      ).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red[300], // Holiday Color
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  e.title ?? '일정',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (provider.dailySchedules.isEmpty &&
                          provider.dailyIncomes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_note,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "일정이 없습니다",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ...provider.dailySchedules.map(
                        (s) => _buildIntegratedScheduleItem(provider, s),
                      ),
                      ...provider.dailyIncomes.map(
                        (i) => _buildLegacyIncomeItem(provider, i),
                      ),
                    ],
                  ),

                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: FloatingActionButton(
                      onPressed: () =>
                          _showUnifiedDialog(context, provider.selectedDate),
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 10, // Enhanced elevation for better visibility
                      child: Icon(Icons.add, color: Colors.grey[800], size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CalendarProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        DateFormat('y년 M월', 'ko_KR').format(provider.focusedDate),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black, size: 24),
          onPressed: () {
            setState(() => _drawerPage = 0);
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.today_outlined, color: Colors.grey[700]),
          onPressed: () =>
              provider.onDateSelected(DateTime.now(), DateTime.now()),
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black, size: 24),
          onPressed: () => _showSearchPopup(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIntegratedDrawer(CalendarProvider provider) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: _drawerPage == 0
          ? _buildDrawerMainPage(provider)
          : _drawerPage == 1
          ? _buildDrawerProfilePage(provider)
          : _buildDrawerTrashPage(provider),
    );
  }

  Widget _buildDrawerMainPage(CalendarProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 20),
          alignment: Alignment.centerLeft,
          child: const Text(
            "캘린더 관리",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  "프로필 필터",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...provider.profiles.map(
                (p) => CheckboxListTile(
                  activeColor: Color(p.colorValue),
                  checkColor: CalendarProvider.isLightColor(p.colorValue)
                      ? Colors.black
                      : Colors.white,
                  value: provider.visibleProfileIds.contains(p.id),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  secondary: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(p.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  onChanged: (val) => provider.toggleProfileVisibility(p.id!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const Divider(height: 32),

              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("프로필 관리"),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => setState(() => _drawerPage = 1),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text("휴지통"),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  provider.loadTrashedSchedules();
                  setState(() => _drawerPage = 2);
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 로그인된 사용자 정보
              if (_getCurrentUserEmail() != null) ...[
                Text(
                  _getCurrentUserEmail()!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
              ],
              // 로그아웃 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('로그아웃'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "울 캘린더 v6.4",
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerProfilePage(CalendarProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 60, 28, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _drawerPage = 0),
              ),
              const Text(
                "프로필 관리",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: CalendarProvider.kAmountBlue,
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const ProfileEditDialog(),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: provider.profiles
                .map(
                  (p) => ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(p.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[300],
                    ),
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => ChangeNotifierProvider.value(
                        value: provider,
                        child: ProfileEditDialog(profile: p),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerTrashPage(CalendarProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 60, 28, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _drawerPage = 0),
              ),
              const Text(
                "휴지통",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        Expanded(
          child: provider.trashedSchedules.isEmpty
              ? Center(
                  child: Text(
                    "휴지통이 비어 있습니다",
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: provider.trashedSchedules
                      .map(
                        (s) => ListTile(
                          title: Text(
                            s.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            DateFormat('M월 d일', 'ko_KR').format(s.date),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    provider.restoreSchedule(s.id!),
                                tooltip: "복구",
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_forever,
                                  color: Colors.red[300],
                                ),
                                onPressed: () =>
                                    _confirmPermanentDelete(provider, s.id!),
                                tooltip: "영구 삭제",
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),

        Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            "삭제된 항목은 30일 후 자동 삭제됩니다",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  void _confirmPermanentDelete(CalendarProvider provider, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPopupBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("영구 삭제"),
        content: const Text("이 일정을 영구적으로 삭제하시겠습니까? 복구할 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              provider.permanentlyDeleteSchedule(id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeHeader(CalendarProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            "월간 합계",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${_formatManWon(provider.monthlyIncomeTotal)}원 (총 ${provider.monthlyCountTotal}건)",
            style: const TextStyle(
              color: CalendarProvider.kAmountPurple,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ), // Light Purple as requested
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    CalendarProvider provider,
    DateTime date,
    bool isSelected, {
    bool isToday = false,
    bool isOutside = false,
  }) {
    final isHoliday =
        LunarUtils.isHoliday(date) || date.weekday == DateTime.sunday;

    final deviceEvents = _getDeviceEventsForDay(provider, date);
    final localHolidayName = LunarUtils.getHolidayName(date);

    String? holidayName = localHolidayName;
    if (holidayName == null && deviceEvents.isNotEmpty) {
      holidayName = deviceEvents.first.title;
    }

    // 날짜 텍스트 색상 결정
    Color textColor;
    if (isSelected) {
      textColor = Colors.black;
    } else if (isHoliday || (holidayName != null && holidayName.isNotEmpty)) {
      // 공휴일인 경우 회색보다 빨간색 우선
      textColor = const Color(0xFFFF5252);
    } else if (isOutside) {
      // 현재 달이 아닌 경우 회색
      textColor = Colors.grey[400]!;
    } else {
      textColor = Colors.black;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
      alignment: Alignment.topCenter,
      decoration: isSelected
          ? BoxDecoration(
              color: kSelectionGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: (isToday || isSelected)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (holidayName != null && holidayName.isNotEmpty) ...[
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    holidayName,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFFFF5252),
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(BuildContext context, DateTime date) {
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    // 캐시된 데이터에서 해당 날짜의 일정 필터링
    final events = provider.cachedMonthlySchedules.where((s) {
      return isSameDay(s.date, date) &&
          provider.visibleProfileIds.contains(s.profileId);
    }).toList();

    if (events.isEmpty) return const SizedBox();

    // 최대 3개까지만 표시 (공간 제약)
    final visibleEvents = events.take(3).toList();
    final overflowCount = events.length - 3;

    return Positioned(
      top: 26, // Further pushed down from the day number to avoid overlap
      left: 2,
      right: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleEvents.map((s) {
            final profile = provider.getProfileById(s.profileId);
            final isLight = CalendarProvider.isLightColor(profile.colorValue);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(profile.colorValue).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                s.title,
                style: TextStyle(
                  color: isLight ? Colors.black : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            );
          }),
          if (overflowCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 0.5),
              child: Text(
                "+$overflowCount",
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntegratedScheduleItem(
    CalendarProvider provider,
    ScheduleModel s,
  ) {
    if (!provider.visibleProfileIds.contains(s.profileId)) {
      return const SizedBox();
    }

    final profile = provider.getProfileById(s.profileId);
    final hasIncome = s.incomeAmount != null && s.incomeAmount! > 0;

    return GestureDetector(
      onTap: () =>
          _showUnifiedDialog(context, provider.selectedDate, editSchedule: s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // 세로 중앙 정렬
          children: [
            Container(
              width: 3.5,
              height: 36, // One UI style marker height
              decoration: BoxDecoration(
                color: Color(profile.colorValue),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2), // 4 -> 2
                  Row(
                    children: [
                      if (s.startTime != null && s.startTime!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            s.startTime!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      if (s.locationName != null && s.locationName!.isNotEmpty)
                        Expanded(
                          child: Text(
                            s.locationName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (s.memo != null && s.memo!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2), // 6 -> 2
                      child: Text(
                        s.memo!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (hasIncome)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  "+${_formatManWon(s.incomeAmount!)}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ), // Black as requested
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyIncomeItem(CalendarProvider provider, IncomeModel i) {
    if (!provider.visibleProfileIds.contains(i.profileId)) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8),
      child: Text(
        "기타 수입: +${NumberFormat.decimalPattern('ko_KR').format(i.amount)}",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[400],
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildStandaloneIncomeIndicator(CalendarProvider provider) {
    double sum = provider.dailyIncomes.fold(0.0, (p, c) => p + c.amount);
    if (sum == 0) {
      return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "기타 +${sum.toInt()}",
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    );
  }

  void _showUnifiedDialog(
    BuildContext context,
    DateTime date, {
    ScheduleModel? editSchedule,
  }) {
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: UnifiedEntryDialog(
          initialDate: date,
          editSchedule: editSchedule,
        ),
      ),
    );
  }

  void _showSearchPopup(BuildContext context) {
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const SearchDialog(),
      ),
    );
  }

  void _showProfileBreakdownPopup(CalendarProvider provider) {
    if (provider.monthlyIncomeTotal == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("이번 달 수입 내역이 없습니다.")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kPopupBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "프로필별 수입",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    provider.profileMonthlyTotals,
                    provider,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ...provider.profileMonthlyTotals.entries.map((e) {
                final p = provider.getProfileById(e.key);
                final percent = (e.value / provider.monthlyIncomeTotal * 100)
                    .toStringAsFixed(1);
                final count = provider.profileMonthlyCounts[e.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(p.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${count}건",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      Text(
                        "${_formatManWon(e.value)}원",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "($percent%)",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("닫기"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<int, double> data;
  final CalendarProvider provider;

  _PieChartPainter(this.data, this.provider);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -math.pi / 2;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final profile = provider.getProfileById(entry.key);
      final paint = Paint()
        ..color = Color(profile.colorValue)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    final holePaint = Paint()..color = kPopupBg;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  static const Color kPopupBg = Color(0xFFF5F7FA);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
