import 'package:flutter/material.dart';
import 'package:parent_helper/services/data_repository.dart';
import 'package:provider/provider.dart';
import '../../models/child.dart';
import '../../models/institution.dart';
import '../../models/schedule.dart';
import '../../widgets/schedule_list_item.dart';
import '../add_edit_schedule_screen.dart';

class TodayScheduleTab extends StatefulWidget {
  const TodayScheduleTab({super.key});

  @override
  State<TodayScheduleTab> createState() => _TodayScheduleTabState();
}

class _TodayScheduleTabState extends State<TodayScheduleTab> {
  String? _selectedChildId;
  String? _selectedInstitutionId;
  ScheduleType? _selectedType; // 등/하원 필터 상태 변수 추가

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<DataRepository>(context);
    final todayWeekday = DateTime.now().weekday;

    return Column(
      children: [
        _buildFilterBar(firestoreService),
        Expanded(
          child: StreamBuilder<List<Schedule>>(
            stream: firestoreService.getAllSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    '등록된 일정이 없습니다.', // (전체 일정이 없을 때)
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }
              final allSchedules = snapshot.data!;

              // Dart에서 3중 필터링 수행
              final filteredSchedules = allSchedules.where((schedule) {
                // 1. 요일 필터 (가장 중요)
                final matchDay = schedule.daysOfWeek.contains(todayWeekday);

                // 2. 자녀 필터
                final matchChild = _selectedChildId == null ||
                    schedule.childId == _selectedChildId;

                // 3. 기관 필터
                final matchInstitution = _selectedInstitutionId == null ||
                    schedule.institutionId == _selectedInstitutionId;

                // 4. 등/하원 필터 추가
                final matchType = _selectedType == null || schedule.type == _selectedType;

                return matchDay && matchChild && matchInstitution && matchType;
              }).toList();

              // 1순위: 시간, 2순위: 아이 이름 순으로 정렬
              filteredSchedules.sort((a, b) {
                int timeA = a.time.hour * 60 + a.time.minute;
                int timeB = b.time.hour * 60 + b.time.minute;
                int timeCompare = timeA.compareTo(timeB);

                if (timeCompare != 0) {
                  return timeCompare;
                }
                return a.childName.compareTo(b.childName);
              });

              if (filteredSchedules.isEmpty) {
                return const Center(
                  child: Text(
                    '오늘 등록된 일정이 없습니다.', // (필터링 결과가 없을 때)
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredSchedules.length,
                itemBuilder: (context, index) {
                  final schedule = filteredSchedules[index];
                  return ScheduleListItem(
                    schedule: schedule,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddEditScheduleScreen(
                            scheduleToEdit: schedule,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 필터 바 위젯
  Widget _buildFilterBar(DataRepository firestoreService) {
    final roundedDropdownTheme = InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // 1. 등/하원 필터 (SegmentedButton) 추가
          SegmentedButton<ScheduleType?>(
            segments: const [
              ButtonSegment<ScheduleType?>(
                value: null, // '전체'
                label: Text('전체'),
                icon: Icon(Icons.clear_all),
              ),
              ButtonSegment<ScheduleType?>(
                value: ScheduleType.pickup, // '등원/픽업'
                label: Text('등원'),
                icon: Icon(Icons.directions_car),
              ),
              ButtonSegment<ScheduleType?>(
                value: ScheduleType.dropoff, // '하원'
                label: Text('하원'),
                icon: Icon(Icons.school),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (Set<ScheduleType?> newSelection) {
              setState(() => _selectedType = newSelection.first);
            },
            // 꽉 차게 보이도록 스타일 조정
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 12), // 필터 사이 간격
          // 자녀 필터
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Child>>(
                  stream: firestoreService.getChildren(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink(); // 로딩 중 UI 생략
                    }
                    final children = snapshot.data!;

                    final List<DropdownMenuEntry<String?>> childEntries = [
                      const DropdownMenuEntry<String?>(
                        value: null,
                        label: '모든 자녀',
                      ),
                      ...children.map((child) => DropdownMenuEntry<String?>(
                        value: child.id,
                        label: child.name,
                      )),
                    ];

                    return DropdownMenu<String?>(
                      inputDecorationTheme: roundedDropdownTheme,
                      alignmentOffset: const Offset(0, 0), // 메뉴를 60픽셀 아래로 강제 이동
                      initialSelection: _selectedChildId,
                      expandedInsets: EdgeInsets.zero,  // expandedInsets으로 Expanded 위젯을 꽉 채움
                      hintText: '자녀 선택',
                      dropdownMenuEntries: childEntries,
                      onSelected: (String? value) {
                        setState(() => _selectedChildId = value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 기관 필터
              Expanded(
                child: StreamBuilder<List<Institution>>(
                  stream: firestoreService.getInstitutions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final institutions = snapshot.data!;

                    final List<DropdownMenuEntry<String?>> instEntries = [
                      const DropdownMenuEntry<String?>(
                        value: null,
                        label: '모든 기관',
                      ),
                      ...institutions.map((inst) => DropdownMenuEntry<String?>(
                        value: inst.id,
                        label: inst.name,
                      )),
                    ];

                    return DropdownMenu<String?>(
                      inputDecorationTheme: roundedDropdownTheme,
                      alignmentOffset: const Offset(0, 0), // 메뉴를 60픽셀 아래로 강제 이동
                      initialSelection: _selectedInstitutionId,
                      expandedInsets: EdgeInsets.zero,  // expandedInsets으로 Expanded 위젯을 꽉 채움
                      hintText: '기관 선택',
                      dropdownMenuEntries: instEntries,
                      onSelected: (String? value) {
                        setState(() => _selectedInstitutionId = value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

