import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child.dart';
import '../../models/institution.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../services/data_repository.dart';
import '../../widgets/schedule_list_item.dart';
import '../add_edit_schedule_screen.dart';
import '../home_screen.dart';

class TodayScheduleTab extends StatefulWidget {
  const TodayScheduleTab({super.key});

  @override
  State<TodayScheduleTab> createState() => _TodayScheduleTabState();
}

class _TodayScheduleTabState extends State<TodayScheduleTab> {
  String? _selectedChildId;
  String? _selectedInstitutionId;
  ScheduleType? _selectedType; // 등/하원 필터 상태 변수 추가

  Future<void> _onAddSchedulePressed(DataRepository dataRepository) async {
    final children = await dataRepository.getChildren().first;
    final institutions = await dataRepository.getInstitutions().first;

    if (!mounted) return;

    if (children.isEmpty || institutions.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('안내'),
          content: const Text('일정을 등록하려면 먼저 자녀와 기관을 1개 이상 등록해야 합니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final homeState = context.findAncestorStateOfType<HomeScreenState>();
                homeState?.onItemTapped(3);
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AddEditScheduleScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // [중요] 로그인 상태 변경 시 리빌드
    Provider.of<AppUser?>(context);

    final dataRepository = Provider.of<DataRepository>(context);
    final todayWeekday = DateTime.now().weekday;

    return StreamBuilder<List<Schedule>>(
        stream: dataRepository.getAllSchedules(),
        builder: (context, snapshot) {
          // 데이터 준비
          final allSchedules = snapshot.data ?? [];

          // 필터링된 리스트 (화면에 보여줄 것)
          final filteredSchedules = allSchedules.where((schedule) {
            final matchDay = schedule.daysOfWeek.contains(todayWeekday);
            final matchChild = _selectedChildId == null ||
                schedule.childId == _selectedChildId;
            final matchInstitution = _selectedInstitutionId == null ||
                schedule.institutionId == _selectedInstitutionId;
            final matchType = _selectedType == null ||
                schedule.type == _selectedType;
            return matchDay && matchChild && matchInstitution && matchType;
          }).toList();

          // 정렬
          filteredSchedules.sort((a, b) {
            int timeA = a.time.hour * 60 + a.time.minute;
            int timeB = b.time.hour * 60 + b.time.minute;
            return (timeA != timeB) ? timeA.compareTo(timeB) : a.childName
                .compareTo(b.childName);
          });

          // [공유용 리스트] 필터와 상관없이 '오늘' 일정 전체를 공유하고 싶다면
          // 여기서 별도로 todaySchedules를 뽑아야 합니다.
          // 하지만 사용자가 '하원'만 보고 있다면 하원 리스트만 공유하는 게 자연스러울 수 있습니다.
          // 여기서는 '현재 화면에 보이는 리스트'를 공유하도록 구현합니다.

          return Column(
            children: [
              // 필터 바 + 공유 버튼
              _buildFilterBar(dataRepository),

              // 고정된 '새 일정 등록' 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _onAddSchedulePressed(dataRepository),
                    icon: const Icon(Icons.add),
                    label: const Text('새 일정 등록'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(),

              // 리스트
              Expanded(
                child: StreamBuilder<List<Schedule>>(
                  stream: dataRepository.getAllSchedules(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // 데이터가 없어도 빈 리스트로 처리하여 필터링 로직이 돌도록 함
                    final allSchedules = snapshot.data ?? [];

                    if (allSchedules.isEmpty) {
                      return const Center(
                        child: Text(
                          '등록된 일정이 없습니다.', // (전체 일정이 없을 때)
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    // Dart에서 3중 필터링 수행
                    final filteredSchedules = allSchedules.where((schedule) {
                      // 1. 요일 필터 (가장 중요)
                      final matchDay = schedule.daysOfWeek.contains(
                          todayWeekday);

                      // 2. 자녀 필터
                      final matchChild = _selectedChildId == null ||
                          schedule.childId == _selectedChildId;

                      // 3. 기관 필터
                      final matchInstitution = _selectedInstitutionId == null ||
                          schedule.institutionId == _selectedInstitutionId;

                      // 4. 등/하원 필터 추가
                      final matchType = _selectedType == null || schedule
                          .type == _selectedType;

                      return matchDay && matchChild && matchInstitution &&
                          matchType;
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
                                builder: (context) =>
                                    AddEditScheduleScreen(
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
        },
    );
  }

  // 필터 바 위젯
  // 공유 버튼 추가를 위해 schedules 인자 추가
  Widget _buildFilterBar(DataRepository dataRepository) {
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
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<Child>>(
                  stream: dataRepository.getChildren(),
                  builder: (context, snapshot) {
                    final children = snapshot.data ?? [];
                    final childEntries = [
                      const DropdownMenuEntry(value: null, label: '모든 자녀'),
                      ...children.map((child) => DropdownMenuEntry(value: child.id, label: child.name)),
                    ];
                    return DropdownMenu<String?>(
                      inputDecorationTheme: roundedDropdownTheme,
                      alignmentOffset: const Offset(0, 60),
                      initialSelection: _selectedChildId,
                      expandedInsets: EdgeInsets.zero,
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
              Expanded(
                child: StreamBuilder<List<Institution>>(
                  stream: dataRepository.getInstitutions(),
                  builder: (context, snapshot) {
                    final institutions = snapshot.data ?? [];
                    final instEntries = [
                      const DropdownMenuEntry(value: null, label: '모든 기관'),
                      ...institutions.map((inst) => DropdownMenuEntry(value: inst.id, label: inst.name)),
                    ];
                    return DropdownMenu<String?>(
                      inputDecorationTheme: roundedDropdownTheme,
                      alignmentOffset: const Offset(0, 60),
                      initialSelection: _selectedInstitutionId,
                      expandedInsets: EdgeInsets.zero,
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
