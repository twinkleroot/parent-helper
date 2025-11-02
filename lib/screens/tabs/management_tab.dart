import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/child.dart';
import '../../models/institution.dart';
import '../../services/firestore_service.dart';
import '../../utils/logger.dart';

class ManagementTab extends StatelessWidget {
  const ManagementTab({super.key});

  // 전화번호 자동 포맷 헬퍼 (예: 010-1234-5678)
  String _formatPhoneNumber(String phoneNumber) {
    // 숫자만 추출
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length == 11) { // 010-xxxx-xxxx
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    } else if (digitsOnly.length == 10) {
      if (digitsOnly.startsWith('02')) { // 02-xxxx-xxxx
        return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 6)}-${digitsOnly.substring(6)}';
      } else { // 031-xxx-xxxx 등
        return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
      }
    } else if (digitsOnly.length == 8) { // 1588-xxxx 등
      return '${digitsOnly.substring(0, 4)}-${digitsOnly.substring(4)}';
    }
    // 그 외는 원본 반환 (하이픈 등 제거된)
    return digitsOnly;
  }

  // 전화를 거는 헬퍼 함수
  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    // 전화번호에서 공백, 하이픈 등 불필요한 문자 제거
    final String sanitizedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: sanitizedNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        logger.e('Could not launch $launchUri');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('전화를 걸 수 없습니다: $phoneNumber')),
          );
        }
      }
    } catch (e) {
      logger.e('Error launching phone call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전화 앱을 여는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- 자녀 관리 ---
        _buildSectionHeader(
          context,
          title: '나의 자녀',
          onAdd: () {
            // 자녀 추가 화면/다이얼로그 표시
            _showAddEditChildDialog(context, firestoreService, childToEdit: null);
          },
        ),
        _buildChildList(firestoreService),

        const SizedBox(height: 24),

        // --- 기관 관리 ---
        _buildSectionHeader(
          context,
          title: '기관 관리 (학교, 학원, 유치원 등)',
          onAdd: () {
            // 기관 추가 다이얼로그 표시
            _showAddEditInstitutionDialog(context, firestoreService, institutionToEdit: null);
          },
        ),
        _buildInstitutionList(firestoreService),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onAdd,
          tooltip: '추가하기',
        ),
      ],
    );
  }

  // 자녀 목록
  Widget _buildChildList(FirestoreService firestoreService) {
    return StreamBuilder<List<Child>>(
      stream: firestoreService.getChildren(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('자녀를 추가해주세요.'));
        }
        final children = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          itemBuilder: (context, index) {
            final child = children[index];
            return Card(
              child: ListTile(
                title: Text(child.name),
                // onTap으로 수정 다이얼로그
                onTap: () {
                  _showAddEditChildDialog(context, firestoreService, childToEdit: child);
                },
                // 길게 눌러 삭제
                onLongPress: () => _showDeleteConfirmation(
                  context,
                  title: '자녀 삭제',
                  content: '${child.name} 님을 목록에서 삭제하시겠습니까?',
                  onConfirm: () => firestoreService.deleteChild(child.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 기관 목록
  Widget _buildInstitutionList(FirestoreService firestoreService) {
    return StreamBuilder<List<Institution>>(
      stream: firestoreService.getInstitutions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('기관을 추가해주세요.'));
        }
        final institutions = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: institutions.length,
          itemBuilder: (context, index) {
            final inst = institutions[index];
            final formattedContact = _formatPhoneNumber(inst.contactNumber);
            return Card(
              child: ListTile(
                title: Text(inst.name),
                subtitle: Text(formattedContact),
                // onTap으로 수정 다이얼로그
                onTap: () {
                  _showAddEditInstitutionDialog(context, firestoreService, institutionToEdit : inst);
                },
                // 길게 눌러 삭제
                onLongPress: () => _showDeleteConfirmation(
                  context,
                  title: '기관 삭제',
                  content: '${inst.name} 기관을 삭제하시겠습니까? (연결된 일정이 있다면 함께 정리해주세요)', // TODO: 일정 자동 삭제 로직?
                  onConfirm: () => firestoreService.deleteInstitution(inst.id),
                ),
                // 전화 걸기 아이콘 버튼
                trailing: inst.contactNumber.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.phone),
                        tooltip: '전화 걸기',
                        onPressed: () {
                          // ListTile의 onTap과 분리되어 아이콘만 독립적으로 동작
                          _makePhoneCall(context, inst.contactNumber);
                        },
                      )
                    : null, // 전화번호가 없으면 아이콘 숨김
              ),
            );
          },
        );
      },
    );
  }

  // 1. 자녀 추가/수정 다이얼로그
  void _showAddEditChildDialog(BuildContext context, FirestoreService firestoreService, {Child? childToEdit}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: childToEdit?.name ?? '');
    final bool isEditing = childToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? '자녀 정보 수정' : '자녀 추가'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '자녀 이름'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '이름을 입력하세요.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  if (isEditing) {
                    // 수정
                    final updatedChild = Child(id: childToEdit.id, name: name);
                    await firestoreService.updateChild(updatedChild);
                  } else {
                    // 추가
                    await firestoreService.addChild(Child(id: '', name: name));
                  }
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 2. 기관 추가/수정 다이얼로그
  void _showAddEditInstitutionDialog(BuildContext context, FirestoreService firestoreService, {Institution? institutionToEdit}) {
    final formKey = GlobalKey<FormState>();
    final bool isEditing = institutionToEdit != null;
    final nameController = TextEditingController(text: institutionToEdit?.name ?? '');
    final contactController = TextEditingController(text: institutionToEdit != null ? _formatPhoneNumber(institutionToEdit.contactNumber) : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? '기관 정보 수정' : '기관 추가'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // 다이얼로그 크기 고정
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '기관 이름'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '기관 이름을 입력하세요.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: '연락처 (선택)'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final contact = _formatPhoneNumber(contactController.text.trim());

                  if (isEditing) {
                    // 수정
                    await firestoreService.updateInstitution(Institution(
                      id: institutionToEdit.id,
                      name: name,
                      contactNumber: contact,
                    ));
                  } else {
                    // 추가
                    await firestoreService.addInstitution(Institution(
                      id: '',
                      name: name,
                      contactNumber: contact,
                    ));
                  }
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 공통 삭제 확인 다이얼로그
  void _showDeleteConfirmation(BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
            onPressed: () {
              onConfirm();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
