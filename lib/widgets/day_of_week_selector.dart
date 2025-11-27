import 'package:flutter/material.dart';

// 스케줄 등록/수정 화면에서 사용될 요일 선택 위젯
class DayOfWeekSelector extends StatelessWidget {
  final List<int> selectedDays; // 1:월, 2:화, ... 7:일
  final Function(List<int>) onChanged;

  const DayOfWeekSelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  static const List<String> _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  static const List<int> _dayValues = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ToggleButtons(
          borderRadius: BorderRadius.circular(8.0),
          isSelected: _dayValues.map((day) => selectedDays.contains(day)).toList(),
          onPressed: (index) {
            final day = _dayValues[index];
            List<int> newSelectedDays = List.from(selectedDays);
            if (newSelectedDays.contains(day)) {
              newSelectedDays.remove(day);
            } else {
              newSelectedDays.add(day);
            }
            onChanged(newSelectedDays);
          },
          // 버튼의 최소 크기 제약 조건을 명시
          constraints: const BoxConstraints(
            minWidth: 40.0,
            minHeight: 40.0,
          ),
          children: _dayLabels.map((label) => Padding(
            // 내부 패딩을 적절히 조절
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(label),
          )).toList(),
        ),
      ),
    );
  }
}
