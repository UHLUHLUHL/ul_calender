import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../models/schedule_model.dart';

class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  static const Color kPopupBg = Color(0xFFF5F7FA);
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CalendarProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 32,
            bottom: bottomInset + 32,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 500),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: "무엇을 찾으시나요?",
                            hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => provider.search(val),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Flexible(
                    child: provider.searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? "검색어를 입력하세요"
                                  : "검색 결과가 없습니다",
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: provider.searchResults.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) => _buildSearchResultItem(
                              ctx,
                              provider,
                              provider.searchResults[i],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    CalendarProvider provider,
    ScheduleModel s,
  ) {
    final profile = provider.getProfileById(s.profileId);
    final dateStr = DateFormat('M월 d일 (E)', 'ko_KR').format(s.date);

    return InkWell(
      onTap: () {
        provider.onDateSelected(s.date, s.date);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                color: Color(profile.colorValue),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
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
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFDDDDDD)),
          ],
        ),
      ),
    );
  }
}
