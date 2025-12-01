import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../models/child.dart';
import '../models/institution.dart';
import '../services/ad_service.dart';
import '../services/data_repository.dart';
import '../services/notification_service.dart';
import '../widgets/day_of_week_selector.dart'; // 위젯 (생략)
import '../utils/logger.dart';

class AddEditScheduleScreen extends StatefulWidget {
  final Schedule? scheduleToEdit;
  const AddEditScheduleScreen({super.key, this.scheduleToEdit});

  @override
  State<AddEditScheduleScreen> createState() => _AddEditScheduleScreenState();
}

class _AddEditScheduleScreenState extends State<AddEditScheduleScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form State
  Child? _selectedChild;
  Institution? _selectedInstitution;
  ScheduleType _type = ScheduleType.pickup;
  TimeOfDay _time = TimeOfDay.now();
  List<int> _daysOfWeek = []; // 1:월 ~ 7:일
  int _leadTime = 10;
  bool _isEnabled = true;
  late TextEditingController _memoController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController();

    if (widget.scheduleToEdit != null) {
      // 수정 모드: 기존 값으로 폼 채우기
      // (단순화를 위해 ID/Name 매칭 대신 미리 저장된 값 사용)
      // (실제 앱에서는 ID를 기준으로 Child/Institution 객체를 찾아야 함)
      _selectedChild = Child(id: widget.scheduleToEdit!.childId, name: widget.scheduleToEdit!.childName);
      _selectedInstitution = Institution(id: widget.scheduleToEdit!.institutionId, name: widget.scheduleToEdit!.institutionName);
      _type = widget.scheduleToEdit!.type;
      _time = widget.scheduleToEdit!.time;
      _daysOfWeek = widget.scheduleToEdit!.daysOfWeek;
      _leadTime = widget.scheduleToEdit!.notificationLeadTimeInMinutes;
      _isEnabled = widget.scheduleToEdit!.isEnabled;
      _memoController.text = widget.scheduleToEdit!.memo;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && picked != _time) {
      setState(() {
        _time = picked;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_formKey.currentState!.validate() && _selectedChild != null && _selectedInstitution != null && _daysOfWeek.isNotEmpty) {
      setState(() { _isLoading = true; });

      final dataRepository = context.read<DataRepository>();
      final notificationService = context.read<NotificationService>();
      final adService = context.read<AdService>();

      Schedule schedule = Schedule(
        id: widget.scheduleToEdit?.id ?? '', // ID가 비어있으면 Firestore가 생성
        childId: _selectedChild!.id,
        childName: _selectedChild!.name,
        institutionId: _selectedInstitution!.id,
        institutionName: _selectedInstitution!.name,
        type: _type,
        daysOfWeek: _daysOfWeek,
        time: _time,
        notificationLeadTimeInMinutes: _leadTime,
        isEnabled: _isEnabled,
        memo: _memoController.text.trim(),
      );

      try {
        if (widget.scheduleToEdit == null) {
          // --- 생성 ---
          // 1. Firestore에 추가 (새 ID 반환받음)
          final String newScheduleId = await dataRepository.addSchedule(schedule);

          // 2. ID를 포함한 객체로 새 알림 예약
          Schedule newScheduleWithId = Schedule(
            id: newScheduleId,
            childId: schedule.childId,
            childName: schedule.childName,
            institutionId: schedule.institutionId,
            institutionName: schedule.institutionName,
            type: schedule.type,
            daysOfWeek: schedule.daysOfWeek,
            time: schedule.time,
            notificationLeadTimeInMinutes: schedule.notificationLeadTimeInMinutes,
            isEnabled: schedule.isEnabled,
            memo: schedule.memo,
          );
          // 생성 시에도 isEnabled 체크
          if (newScheduleWithId.isEnabled) {
            await notificationService.scheduleWeeklyNotification(newScheduleWithId);
          }
        } else {
          // --- 기존 스케줄 수정 ---
          // Firestore 업데이트
          await dataRepository.updateSchedule(schedule);
          // 기존 알림 모두 취소
          await notificationService.cancelNotificationsForSchedule(schedule);

          // 새 정보로 알림 다시 예약
          if (schedule.isEnabled) {
            await notificationService.scheduleWeeklyNotification(schedule);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 저장되었습니다.')),
          );
          // 화면을 먼저 닫음 (사용자 경험상 저장이 끝났으므로)
          Navigator.pop(context);

          // 화면이 닫힌 후 전면 광고 표시 시도 (빈도 체크는 서비스 내부에서 함)
          // 화면 전환 중에 광고가 뜨면 자연스러움
          await adService.checkAndShowInterstitialAd();
        }
      } catch (e) {
        logger.e('스케줄 저장 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 중 오류 발생: $e')),
          );
        }
      } finally {
        // 화면이 이미 pop 되었을 수 있으므로 mounted 체크
        if (mounted) setState(() { _isLoading = false; });
      }

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 올바르게 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Firestore에서 자녀 및 기관 목록 가져오기
    final firestoreService = Provider.of<DataRepository>(context);

    // 둥근 모서리 테마 정의
    final roundedDropdownTheme = InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheduleToEdit == null ? '일정 추가' : '일정 수정'),
        actions: [
          if (widget.scheduleToEdit != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final bool confirm = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('일정 삭제'),
                    content: const Text('이 일정을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ) ?? false;

                if (confirm && mounted) {
                  await Provider.of<NotificationService>(context, listen: false)
                      .cancelNotificationsForSchedule(widget.scheduleToEdit!);
                  await firestoreService.deleteSchedule(widget.scheduleToEdit!.id);
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 자녀 선택
            StreamBuilder<List<Child>>(
              stream: firestoreService.getChildren(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final children = snapshot.data!;
                final List<DropdownMenuEntry<Child?>> childEntries =
                children
                    .map((child) => DropdownMenuEntry<Child?>(
                      value: child,
                      label: child.name,
                    ))
                    .toList();

                // Stream에서 받아온 목록에서 현재 ID와 일치하는 객체를 찾음
                Child? currentSelection;
                if (_selectedChild != null &&
                    children.any((c) => c.id == _selectedChild!.id)) {
                  currentSelection = children
                      .firstWhere((c) => c.id == _selectedChild!.id);
                }

                return DropdownMenu<Child?>(
                  // 둥근 모서리 테마 적용
                  inputDecorationTheme: roundedDropdownTheme,
                  // 메뉴를 아래로 강제
                  alignmentOffset: const Offset(0, 0),
                  // 너비 채우기
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: currentSelection,
                  hintText: '자녀 선택',
                  dropdownMenuEntries: childEntries,
                  onSelected: (Child? value) {
                    setState(() => _selectedChild = value);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // 기관 선택
            StreamBuilder<List<Institution>>(
              stream: firestoreService.getInstitutions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final institutions = snapshot.data!;
                final List<DropdownMenuEntry<Institution?>> instEntries =
                institutions
                    .map((inst) => DropdownMenuEntry<Institution?>(
                  value: inst,
                  label: inst.name,
                ))
                    .toList();

                // Stream에서 받아온 목록에서 현재 ID와 일치하는 객체를 찾음
                Institution? currentSelection;
                if (_selectedInstitution != null &&
                    institutions
                        .any((i) => i.id == _selectedInstitution!.id)) {
                  currentSelection = institutions.firstWhere(
                          (i) => i.id == _selectedInstitution!.id);
                }

                return DropdownMenu<Institution?>(
                  // 둥근 모서리 테마 적용
                  inputDecorationTheme: roundedDropdownTheme,
                  // 메뉴를 아래로 강제
                  alignmentOffset: const Offset(0, 0),
                  // 너비 채우기
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: currentSelection,
                  hintText: '기관 선택',
                  dropdownMenuEntries: instEntries,
                  onSelected: (Institution? value) {
                    setState(() => _selectedInstitution = value);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // 등원/하원
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(value: ScheduleType.pickup, label: Text('등원/픽업')),
                ButtonSegment(value: ScheduleType.dropoff, label: Text('하원')),
              ],
              selected: {_type},
              onSelectionChanged: (Set<ScheduleType> newSelection) {
                setState(() => _type = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            // 요일 선택 (커스텀 위젯)
            DayOfWeekSelector(
              selectedDays: _daysOfWeek,
              onChanged: (days) => setState(() => _daysOfWeek = days),
            ),
            if (_daysOfWeek.isEmpty)
              const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('요일을 하나 이상 선택하세요.', style: TextStyle(color: Colors.red, fontSize: 12)),
                      )
                    ),
            const SizedBox(height: 16),
            // 시간 선택
            ListTile(
              title: const Text('알림 시간'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),
            // 미리 알림 시간
            DropdownMenu<int>(
              inputDecorationTheme: roundedDropdownTheme,
              alignmentOffset: const Offset(0, 0),
              expandedInsets: EdgeInsets.zero,
              initialSelection: _leadTime,
              // [수정] hintText 대신 label 사용 (InputDecorationTheme과 더 잘 맞음)
              label: const Text('미리 알림'),
              dropdownMenuEntries:
              [5, 10, 15, 20, 30, 60].map((min) {
                return DropdownMenuEntry<int>(
                  value: min,
                  label: '$min 분 전',
                );
              }).toList(),
              onSelected: (int? value) {
                setState(() => _leadTime = value ?? 10);
              },
            ),
            const SizedBox(height: 16),
            // 메모 필드
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택 사항)',
                hintText: '예: 차량 번호, 선생님 연락처 등',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // 알림 활성화
            SwitchListTile(
              title: const Text('알림 활성화'),
              value: _isEnabled,
              onChanged: (value) => setState(() => _isEnabled = value),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSchedule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}
