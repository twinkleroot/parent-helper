import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../models/child.dart';
import '../models/institution.dart';
import '../services/firestore_service.dart';
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

      final firestoreService = context.read<FirestoreService>();
      final notificationService = context.read<NotificationService>();

      Schedule schedule = Schedule(
        id: widget.scheduleToEdit?.id ?? '', // ID가 비어있으면 Firestore가 생성
        // id: widget.schedule?.id, // 수정 시 기존 ID 사용
        childId: _selectedChild!.id,
        childName: _selectedChild!.name,
        institutionId: _selectedInstitution!.id,
        institutionName: _selectedInstitution!.name,
        type: _type,
        daysOfWeek: _daysOfWeek,
        time: _time,
        notificationLeadTimeInMinutes: _leadTime,
        // isEnabled: _isEnabled,
        isEnabled: widget.scheduleToEdit?.isEnabled ?? true, // 기본값 true
        memo: _memoController.text.trim(),
      );

      try {
        if (widget.scheduleToEdit == null) {
          // --- 생성 ---
          // 1. Firestore에 추가 (새 ID 반환받음)
          final docRef = await firestoreService.addSchedule(schedule);

          // 2. ID를 포함한 객체로 새 알림 예약
          Schedule newScheduleWithId = Schedule(
            id: docRef.id, // Firestore에서 생성된 ID
            childId: schedule.childId,
            childName: schedule.childName,
            institutionId: schedule.institutionId,
            institutionName: schedule.institutionName,
            type: schedule.type,
            daysOfWeek: schedule.daysOfWeek,
            time: schedule.time,
            notificationLeadTimeInMinutes: schedule.notificationLeadTimeInMinutes,
            isEnabled: schedule.isEnabled,
          );
          await notificationService.scheduleWeeklyNotification(newScheduleWithId);
        } else {
          // --- 기존 스케줄 수정 ---
          // Firestore 업데이트
          await firestoreService.updateSchedule(schedule);
          // 기존 알림 모두 취소
          await notificationService.cancelNotificationsForSchedule(schedule);

          // 1. 기존 알림 취소
          // await notificationService.cancelNotificationsForSchedule(widget.scheduleToEdit!);

          // 새 정보로 알림 다시 예약
          if (schedule.isEnabled) {
            await notificationService.scheduleWeeklyNotification(schedule);
            }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 저장되었습니다.')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        logger.e('스케줄 저장 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 중 오류 발생: $e')),
          );
        }
      } finally {
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
    final firestoreService = Provider.of<FirestoreService>(context);

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
                return DropdownButtonFormField<Child>(
                  // ID 기반으로 매칭
                  value: _selectedChild != null && snapshot.data!.any((c) => c.id == _selectedChild!.id)
                      ? snapshot.data!.firstWhere((c) => c.id == _selectedChild!.id)
                      : null,
                  hint: const Text('자녀 선택'),
                  items: snapshot.data!.map((child) {
                    return DropdownMenuItem<Child>(
                      value: child,
                      child: Text(child.name),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedChild = value),
                  validator: (value) => value == null ? '자녀를 선택하세요' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            // 기관 선택
            StreamBuilder<List<Institution>>(
              stream: firestoreService.getInstitutions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<Institution>(
                  // ID 기반으로 매칭
                  value: _selectedInstitution != null && snapshot.data!.any((i) => i.id == _selectedInstitution!.id)
                      ? snapshot.data!.firstWhere((i) => i.id == _selectedInstitution!.id)
                      : null,
                  hint: const Text('기관 선택'),
                  items: snapshot.data!.map((inst) {
                    return DropdownMenuItem<Institution>(
                      value: inst,
                      child: Text(inst.name),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedInstitution = value),
                  validator: (value) => value == null ? '기관을 선택하세요' : null,
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
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('요일을 하나 이상 선택하세요.', style: TextStyle(color: Colors.red, fontSize: 12)),
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
            DropdownButtonFormField<int>(
              value: _leadTime,
              decoration: const InputDecoration(labelText: '미리 알림'),
              items: [5, 10, 15, 20, 30].map((min) {
                return DropdownMenuItem<int>(
                  value: min,
                  child: Text('$min 분 전'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _leadTime = value ?? 10),
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
