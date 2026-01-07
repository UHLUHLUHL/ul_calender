import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile_model.dart';
import '../providers/calendar_provider.dart';

class ProfileEditDialog extends StatefulWidget {
  final ProfileModel? profile;
  const ProfileEditDialog({super.key, this.profile});

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  static const Color kPopupBg = Color(0xFFF5F7FA);

  late TextEditingController _nameController;
  int _selectedColor = 0xFF4285F4;

  // Exact Samsung Calendar Colors from user's screenshot
  static const List<int> kSamsungPresetColors = [
    0xFF4285F4, // Light Blue (selected ring style)
    0xFFEA4335, // Red
    0xFFE91E63, // Pink/Magenta
    0xFFFF5722, // Deep Orange
    0xFFFF9800, // Orange
    0xFFFFEB3B, // Yellow
    0xFF4CAF50, // Green
    0xFF00BCD4, // Cyan
    0xFF03A9F4, // Light Blue
    0xFF3F51B5, // Indigo/Blue
    0xFF9C27B0, // Purple/Violet
    0xFFBA68C8, // Light Purple
    0xFF9E9E9E, // Grey
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    if (widget.profile != null) {
      _selectedColor = widget.profile!.colorValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPopupBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? "프로필 수정" : "새 프로필",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      labelText: "이름",
                      labelStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "색상 선택",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Samsung Style Grid Picker
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: kSamsungPresetColors.map((color) {
                      final isSelected = color == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 20,
                                  color: _isLightColor(color)
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEdit)
                        TextButton(
                          onPressed: _showDeleteConfirm,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[400],
                          ),
                          child: const Text("삭제"),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "취소",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _save,
                        child: const Text(
                          "저장",
                          style: TextStyle(
                            color: CalendarProvider.kAmountBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isLightColor(int colorValue) {
    final color = Color(colorValue);
    double luminance = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    return luminance > 0.6;
  }

  void _showDeleteConfirm() {
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    if (provider.profiles.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("최소 하나의 프로필은 있어야 합니다.")));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPopupBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("프로필 삭제"),
        content: const Text("이 프로필의 모든 일정이 함께 삭제됩니다. 계속하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProfile(widget.profile!.id!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("삭제하기"),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    final provider = Provider.of<CalendarProvider>(context, listen: false);

    if (widget.profile != null) {
      provider.updateProfile(
        ProfileModel(
          id: widget.profile!.id,
          name: _nameController.text.trim(),
          colorValue: _selectedColor,
        ),
      );
    } else {
      provider.addNewProfile(_nameController.text.trim(), _selectedColor);
    }
    Navigator.pop(context);
  }
}
