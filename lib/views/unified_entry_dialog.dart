import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/schedule_model.dart';
import '../models/profile_model.dart';
import 'profile_edit_dialog.dart';

class UnifiedEntryDialog extends StatefulWidget {
  final DateTime initialDate;
  final ScheduleModel? editSchedule;

  const UnifiedEntryDialog({
    super.key,
    required this.initialDate,
    this.editSchedule,
  });

  @override
  State<UnifiedEntryDialog> createState() => _UnifiedEntryDialogState();
}

class _UnifiedEntryDialogState extends State<UnifiedEntryDialog> {
  static const Color kPopupBg = Color(0xFFF5F7FA);

  bool get isEdit => widget.editSchedule != null;

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _startTime;
  int? _selectedProfileId; // nullable로 변경하여 초기화 시점 제어

  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CalendarProvider>(context, listen: false);

    if (isEdit) {
      final s = widget.editSchedule!;
      _titleController.text = s.title;
      _memoController.text = s.memo ?? '';
      _locationController.text = s.locationName ?? '';
      _selectedProfileId = s.profileId;
      double displayAmount = 0;
      if (s.incomeAmount != null && s.incomeAmount! > 0) {
        displayAmount = s.incomeAmount! / 10000;
      }

      // 소수점 처리: 정수면 .0 제거
      if (displayAmount > 0) {
        _amountController.text = displayAmount % 1 == 0
            ? displayAmount.toInt().toString()
            : displayAmount.toString();
      } else {
        _amountController.text = '';
      }
      if (s.startTime != null) {
        final parts = s.startTime!.split(':');
        _startTime = DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } else {
      _startTime = null; // Default to no time
      // 프로필이 있으면 첫 번째 프로필 선택
      if (provider.profiles.isNotEmpty) {
        _selectedProfileId =
            provider.currentProfile?.id ?? provider.profiles.first.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: kPopupBg,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    isEdit ? "일정 편집" : "새 일정",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSelector(),
                        const SizedBox(height: 24),

                        TextField(
                          controller: _titleController,
                          focusNode: _titleFocus,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: '일정 제목',
                            hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                        const Divider(height: 24),

                        _buildRow(
                          Icons.access_time_rounded,
                          "시간",
                          _buildTimeDisplay(),
                        ),
                        const SizedBox(height: 16),
                        _buildRow(
                          Icons.payments_outlined,
                          "금액",
                          _buildAmountField(),
                        ),
                        const SizedBox(height: 16),
                        _buildRow(
                          Icons.location_on_outlined,
                          "장소",
                          _buildSimpleField(_locationController, "장소 추가"),
                        ),
                        const SizedBox(height: 16),
                        _buildRow(
                          Icons.notes_rounded,
                          "메모",
                          _buildSimpleField(
                            _memoController,
                            "메모 추가",
                            maxLines: 2,
                          ),
                          alignTop: true,
                        ),
                      ],
                    ),
                  ),

                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    IconData icon,
    String label,
    Widget trailing, {
    bool alignTop = false,
  }) {
    return Row(
      crossAxisAlignment: alignTop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: alignTop ? 2 : 0),
          child: Icon(icon, size: 22, color: Colors.grey[400]),
        ),
        const SizedBox(width: 16),
        Expanded(child: trailing),
      ],
    );
  }

  // Large Time Selection Display (Samsung Alarm Style)
  Widget _buildTimeDisplay() {
    return GestureDetector(
      onTap: _showGrandTimePicker,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _startTime == null
                ? "시간 추가"
                : DateFormat('a h:mm', 'ko_KR').format(_startTime!),
            style: TextStyle(
              fontWeight: _startTime == null
                  ? FontWeight.normal
                  : FontWeight.bold,
              fontSize: 18,
              color: _startTime == null ? Colors.grey[400] : Colors.black,
            ), // Black text as requested
          ),
        ),
      ),
    );
  }

  // Custom Grand Time Picker (Samsung-like Dialogue)
  void _showGrandTimePicker() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kPopupBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "시간 선택",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime:
                      _startTime ??
                      DateTime(
                        widget.initialDate.year,
                        widget.initialDate.month,
                        widget.initialDate.day,
                        9,
                        0,
                      ),
                  onDateTimeChanged: (dt) => setState(() => _startTime = dt),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: CalendarProvider.kAmountBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ), // Black text as requested
      decoration: const InputDecoration(
        hintText: "금액 입력 (옵션)",
        hintStyle: TextStyle(
          color: Color(0xFFDDDDDD),
          fontWeight: FontWeight.normal,
          fontSize: 15,
        ),
        suffixText: "만 원",
        suffixStyle: TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Widget _buildSimpleField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 15),
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Widget _buildProfileSelector() {
    final provider = Provider.of<CalendarProvider>(context);
    return SizedBox(
      height: 65,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: provider.profiles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, index) {
          if (index == provider.profiles.length) {
            return _buildAddButton();
          }
          final p = provider.profiles[index];
          final isSelected = p.id == _selectedProfileId;
          final isLight = _isLightColor(p.colorValue);
          return GestureDetector(
            onTap: () => setState(() => _selectedProfileId = p.id!),
            onLongPress: () => _showEditProfileDialog(p),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(p.colorValue),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(p.colorValue).withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 22,
                          color: isLight ? Colors.black : Colors.white,
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddProfileDialog,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 22, color: Colors.grey[400]),
          ),
          const SizedBox(height: 6),
          const Text("추가", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  bool _isLightColor(int colorValue) {
    final color = Color(colorValue);
    double luminance = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    return luminance > 0.6;
  }

  // Action buttons: All text style, 'Delete' added for edit mode
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (isEdit)
            TextButton(
              onPressed: _confirmDelete,
              child: Text(
                '삭제',
                style: TextStyle(color: Colors.red[300], fontSize: 16),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: _save,
            child: const Text(
              '저장',
              style: TextStyle(
                color: CalendarProvider.kAmountBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPopupBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("일정 삭제"),
        content: const Text("이 일정을 삭제하고 휴지통으로 이동하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
  }

  void _delete() {
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    provider.trashSchedule(widget.editSchedule!);
    Navigator.pop(context);
  }

  void _showAddProfileDialog() {
    showDialog(context: context, builder: (_) => const ProfileEditDialog());
  }

  void _showEditProfileDialog(ProfileModel p) {
    showDialog(
      context: context,
      builder: (_) => ProfileEditDialog(profile: p),
    );
  }

  Future<void> _save() async {
    print("DEBUG: _save called"); // 디버깅용 로그
    if (_titleController.text.trim().isEmpty) {
      print("DEBUG: Title is empty");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("제목을 입력해주세요")));
      return;
    }

    final provider = Provider.of<CalendarProvider>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;

    // 프로필 ID 확인
    final profileId = _selectedProfileId ?? provider.profiles.first.id ?? 0;

    print("DEBUG: Creating schedule model with profileId: $profileId");
    final newSchedule = ScheduleModel(
      id: widget.editSchedule?.id,
      date: widget.initialDate,
      title: _titleController.text.trim(),
      profileId: profileId,
      locationName: _locationController.text.trim(),
      memo: _memoController.text.trim(),
      isAllDay: _startTime == null,
      startTime: _startTime != null
          ? DateFormat('HH:mm').format(_startTime!)
          : null,
      incomeAmount: amount > 0 ? amount * 10000 : null,
    );

    print("DEBUG: Calling provider add/update");
    try {
      if (isEdit) {
        await provider.updateSchedule(newSchedule);
      } else {
        await provider.addSchedule(newSchedule);
      }
      print("DEBUG: Provider call successful");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("DEBUG: Error in save: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("저장 중 오류 발생: $e")));
    }
  }
}
