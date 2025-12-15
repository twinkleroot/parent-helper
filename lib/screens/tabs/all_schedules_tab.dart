import 'package:flutter/material.dart';
import 'package:parent_helper/services/data_repository.dart';
import 'package:provider/provider.dart';
import '../../models/child.dart';
import '../../models/institution.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../services/purchase_service.dart';
import '../../widgets/schedule_list_item.dart';
import '../add_edit_schedule_screen.dart';
import '../home_screen.dart'; // HomeScreenState

// StatefulWidget으로 변경 (필터 상태 관리를 위해)
class AllSchedulesTab extends StatefulWidget {
  const AllSchedulesTab({super.key});

  @override
  State<AllSchedulesTab> createState() => _AllSchedulesTabState();
}

class _AllSchedulesTabState extends State<AllSchedulesTab> {
  String? _selectedChildId;
  String? _selectedInstitutionId;
  ScheduleType? _selectedType; // 등/하원 필터 상태 변수 추가

  // 일정 추가 버튼 핸들러
  Future<void> _onAddSchedulePressed(DataRepository dataRepository) async {
    // 일정 추가 전 제한 체크
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    final schedules = await dataRepository.getAllSchedules().first;
    final children = await dataRepository.getChildren().first;
    final institutions = await dataRepository.getInstitutions().first;

    if (!mounted) return;

    if (children.isEmpty || institutions.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: const Text('안내'),
              content: const Text('일정을 등록하려면 먼저 자녀와 기관을 1개 이상 등록해야 합니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // 설정 탭으로 이동
                    final homeState = context.findAncestorStateOfType<
                        HomeScreenState>();
                    homeState?.onItemTapped(2);
                  },
                  child: const Text('설정으로 이동'),
                ),
              ],
            ),
      );
      return;
    }

    // 2. 일정 개수 제한 체크 (무료: 2개)
    if (!purchaseService.isPremium && schedules.length >= 2) {
      _showPremiumDialog(context, '일정은 2개까지만 등록 가능합니다.\n프리미엄으로 업그레이드하고 제한 없이 이용하세요!');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditScheduleScreen(),
      ),
    );
  }

  // [추가] 프리미엄 다이얼로그 (ManagementTab과 동일한 로직, 재사용하거나 별도 위젯으로 분리 가능)
  void _showPremiumDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('프리미엄 업그레이드'),
          ],
        ),
        content: Text(
          '$message\n\n'
              '✨ 프리미엄 혜택:\n'
              '• 자녀, 기관, 일정 무제한 등록',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text('나중에'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<PurchaseService>(context, listen: false).buyPremium();
            },
            child: const Text('지금 업그레이드'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [중요] 로그인 상태(AppUser)가 변경되면 이 위젯을 다시 빌드하도록 구독합니다.
    // 이를 통해 로그인 직후 DataRepository가 Firestore 데이터를 가져오게 됩니다.
    Provider.of<AppUser?>(context);

    final dataRepository = Provider.of<DataRepository>(context);

    return Column(
      children: [
        // 필터 영역
        _buildFilterBar(dataRepository),
        // [추가] 고정된 '새 일정 등록' 버튼
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
        // 리스트 영역
        Expanded(
          child: StreamBuilder<List<Schedule>>(
            stream: dataRepository.getAllSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allSchedules = snapshot.data ?? [];

              if (allSchedules.isEmpty) {
                return const Center(
                  child: Text(
                    '등록된 일정이 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                );
              }
              final schedules = snapshot.data!;

              // 필터링 로직 적용
              final filteredSchedules = schedules.where((schedule) {
                final matchChild = _selectedChildId == null ||
                    schedule.childId == _selectedChildId;
                final matchInstitution = _selectedInstitutionId == null ||
                    schedule.institutionId == _selectedInstitutionId;
                final matchType = _selectedType == null || schedule.type == _selectedType;
                return matchChild && matchInstitution && matchType;
              }).toList();

              // 1순위: 시간, 2순위: 아이 이름 순으로 정렬
              filteredSchedules.sort((a, b) {
                int timeA = a.time.hour * 60 + a.time.minute;
                int timeB = b.time.hour * 60 + b.time.minute;
                int timeCompare = timeA.compareTo(timeB);

                if (timeCompare != 0) {
                  return timeCompare;
                }
                // 시간이 같으면 이름 순 (오름차순)
                return a.childName.compareTo(b.childName);
              });

              if (filteredSchedules.isEmpty) {
                return const Center(
                  child: Text(
                    '선택한 조건에 맞는 일정이 없습니다.',
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
  Widget _buildFilterBar(DataRepository dateRepository) {
    // 둥근 모서리 테마 정의
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
          Row(
            children: [
              // 자녀 필터
              Expanded(
                child: StreamBuilder<List<Child>>(
                  stream: dateRepository.getChildren(),
                  builder: (context, snapshot) {
                    // [수정] 데이터가 없어도 표시
                    final children = snapshot.data ?? [];

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
                      alignmentOffset: const Offset(0, 0),
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
              // 기관 필터
              Expanded(
                child: StreamBuilder<List<Institution>>(
                  stream: dateRepository.getInstitutions(),
                  builder: (context, snapshot) {
                    // [수정] 데이터가 없어도 표시
                    final institutions = snapshot.data ?? [];

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
                      alignmentOffset: const Offset(0, 0),
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

