import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../models/child.dart';
import '../../models/institution.dart';
// import '../../services/ad_service.dart';
import '../../services/auth_service.dart';
import '../../services/data_repository.dart';
import '../../services/notification_service.dart';
import '../../services/purchase_service.dart';
import '../../utils/logger.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/user_guide_dialog.dart';

class ManagementTab extends StatelessWidget {
  const ManagementTab({super.key});

  // 전화번호 자동 포맷 헬퍼 (예: 010-1234-5678)
  String _formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 11) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    }
    if (digitsOnly.length == 10) {
      if (digitsOnly.startsWith('02')) {
        return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 6)}-${digitsOnly.substring(6)}';
      } else {
        return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
      }
    }
    if (digitsOnly.length == 9) {
      if (digitsOnly.startsWith('02')) {
        return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2, 5)}-${digitsOnly.substring(5)}';
      }
    }
    return phone;
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
    final dataRepository = Provider.of<DataRepository>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 프리미엄 구매 상태 확인용 (선택 사항)
        Consumer<PurchaseService>(
          builder: (context, purchaseService, child) {
            if (purchaseService.isPremium) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 24.0), // 하단 섹션(자녀)과의 간격
                child: Card(
                  color: Colors.amberAccent,
                  child: ListTile(
                    leading: Icon(Icons.workspace_premium, color: Colors.deepOrange, size: 32),
                    title: Text(
                        '프리미엄 사용자',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        )
                    ),
                    subtitle: Text(
                      '모든 기능을 제한 없이 사용 중입니다.\n감사합니다!',
                      style: TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // --- 자녀 관리 ---
        _buildSectionHeader(
          context,
          title: '나의 자녀',
          onAdd: () async {
            // 자녀 추가 전 제한 체크
            final purchaseService = Provider.of<PurchaseService>(context, listen: false);
            final children = await dataRepository.getChildren().first;

            // 프리미엄이 아니고, 자녀가 1명 이상이면 제한 (무료: 1명)
            if (!purchaseService.isPremium && children.isNotEmpty) {
              showPremiumDialog(context, message: '✨ 무료버전은 자녀 1명만 등록 가능합니다.');
            } else {
              // 자녀 추가 화면/다이얼로그 표시
              _showAddEditChildDialog(context, dataRepository);
            }
          },
        ),
        _buildChildList(context, dataRepository),

        const SizedBox(height: 24),

        // --- 기관 관리 ---
        _buildSectionHeader(
          context,
          title: '기관 관리 (학교, 학원, 유치원 등)',
          onAdd: () async {
            final purchaseService = Provider.of<PurchaseService>(context, listen: false);
            final institutions = await dataRepository.getInstitutions().first;

            // 프리미엄이 아니고, 기관이 2개 이상이면 제한 (무료: 2개)
            if (!purchaseService.isPremium && institutions.length >= 2) {
              showPremiumDialog(context, message: '✨ 무료버전은 기관 2개까지만 등록 가능합니다.');
            } else {
              _showAddEditInstitutionDialog(context, dataRepository);
            }
          },
        ),
        _buildInstitutionList(context, dataRepository),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        _buildAccountManagementSection(context),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // --- 섹션 제목 변경 ---
        Text('앱 정보 및 설정', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // 앱 사용 가이드 버튼
        Card(
          child: ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.amber),
            title: const Text('앱 사용 가이드'),
            subtitle: const Text('등하원 알리미 사용 방법을 다시 확인합니다.'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => const UserGuideDialog(),
              );
            },
          ),
        ),

        // const SizedBox(height: 16),

        // const SizedBox(height: 16),

        // --- 배터리 최적화 안내 카드 ---
        Card(
          child: ListTile(
            leading: const Icon(Icons.battery_alert, color: Colors.deepOrange),
            title: const Text('예약 알림이 울리지 않나요?'),
            subtitle: const Text('삼성, 샤오미 등 일부 기기는 배터리 절전을 위해 알림을 차단할 수 있습니다. 여기를 탭하여 설정을 변경하세요.'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('알림이 오지 않는 경우'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '안정적인 알림을 위해, OS의 "배터리 최적화" 설정 변경이 필요합니다.\n\n'
                          '1. "설정으로 이동" 버튼을 누르세요.\n'
                          '2. [배터리] 항목을 선택하세요.\n'
                          '3. [백그라운드 사용 제한] 또는 [배터리 사용량 최적화]를 선택하세요.\n'
                          '4. [등하원 알리미] 앱을 찾아 [제한 없음] 또는 [최적화 안 함]으로 변경해주세요.\n\n'
                          '(삼성 기기는 [절전 예외 앱] 목록에 이 앱을 추가해야 할 수도 있습니다.)',
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('닫기'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    ElevatedButton(
                      child: const Text('설정으로 이동'),
                      onPressed: () {
                        permission_handler.openAppSettings();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 계정 관리 UI 및 로직
  Widget _buildAccountManagementSection(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final isLogged = user != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '계정 관리',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        if (!isLogged)
        // 1. 비로그인 상태: 계정 연동 유도
          Card(
            // color: Colors.white70, // 강조 색상
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white24, width: 1),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.cloud_upload, color: Colors.green),
              ),
              title: const Text(
                '구글 계정 연동하고 데이터 백업하기',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 6.0),
                child: Text(
                  '현재 데이터는 기기에만 저장되어 있습니다.\n앱 삭제나 기기 변경 시 데이터 유실을 방지하려면 계정을 연동해주세요.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              onTap: () => _handleLinkAccount(context),
            ),
          )
        else
        // 2. 로그인 상태: 계정 정보 및 관리
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle, color: Colors.green),
                  title: const Text('구글 계정 연동됨'),
                  subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? '이메일 정보 없음'),
                  trailing: TextButton(
                    onPressed: () => _handleSignOut(context),
                    child: const Text(
                        '로그아웃', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('계정 탈퇴'),
                  subtitle: const Text('모든 데이터(서버/로컬)를 삭제하고 탈퇴합니다.'),
                  leading: const Icon(
                      Icons.delete_forever, color: Colors.red),
                  onTap: () => _showAccountDeletionConfirmation(context),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 계정 연동 (로그인) 핸들러
  Future<void> _handleLinkAccount(BuildContext context) async {
    // 1. 프리미엄 체크
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    if (!purchaseService.isPremium) {
      showPremiumDialog(context, message: '✨ 무료버전에서는 데이터 서버 백업 및 동기화 기능을 이용할 수 없습니다.');
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dataRepository = Provider.of<DataRepository>(context, listen: false);
      // final adService = Provider.of<AdService>(context, listen: false);

      // 로그인 화면으로 넘어갔다가 돌아올 때 광고가 뜨지 않도록 스킵 설정
      // adService.skipNextAppOpenAd();

      // 로그인 시도 (내부적으로 데이터 동기화 syncLocalDataToFirestore 실행됨)
      final user = await authService.signInWithGoogle();

      // 로딩 닫기
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (user != null) {
        // 로그인 성공 시 Repository의 Auth 상태를 수동으로 즉시 갱신
        dataRepository.updateAuth(user);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('계정이 연동되고 데이터가 안전하게 백업되었습니다.')),
          );
        }
      } else {
        // 로그인 취소 또는 실패
      }
    } catch (e) {
      // 로딩 닫기
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      logger.e('계정 연동 실패: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정 연동 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  // 로그아웃 핸들러
  Future<void> _handleSignOut(BuildContext context) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?\n로그아웃 후에는 로컬(기기) 데이터만 사용됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃')),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      // 로그아웃 후에는 자동으로 로컬 DB 모드로 전환됩니다 (DataRepository 로직)
    }
  }

  void _showAccountDeletionConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '정말로 계정을 탈퇴하시겠습니까?\n'
          '모든 자녀, 기관, 일정 정보가 **영구적으로 삭제**되며 복구할 수 없습니다.\n'
          '이 작업을 계속하려면 Google 로그인을 다시 해야 할 수 있습니다.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('계정 탈퇴', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop(true); // 확인
            },
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        // 사용자가 '계정 탈퇴'를 확인했을 때
        _deleteUserAccount(context);
      }
    });
  }

  // 계정 삭제 프로세스 실행
  Future<void> _deleteUserAccount(BuildContext context) async {
    // context가 파괴되기 전에 Navigator와 Messenger를 미리 저장합니다.
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('계정 삭제 중...'),
            ],
          ),
        ),
      ),
    );

    try {
      // 모든 서비스 가져오기
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<DataRepository>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      // 1. 모든 예약된 알림 취소
      await notificationService.cancelAllNotifications();
      logger.i('모든 알림이 취소되었습니다.');

      // 2. 모든 Firestore 데이터 삭제
      await firestoreService.deleteAllUserData();
      logger.i('모든 Firestore 데이터가 삭제되었습니다.');

      // 3. Firebase Auth 계정 삭제 (재인증 포함)
      final bool deleted = await authService.deleteAccount();

      if (navigator.mounted) navigator.pop();

      if (deleted) {
        logger.i('계정 삭제가 성공적으로 완료되었습니다.');
        // AuthGate가 이 시점 이후에 리빌드되며 자동으로 로그인 화면으로 이동시킵니다.
      } else {
        logger.w('사용자 재인증 취소 등으로 계정 삭제가 완료되지 않았습니다.');
      }
    } catch (e) {
      logger.e('계정 삭제 프로세스 중 오류 발생: $e');
      // 오류 발생 시에도 미리 저장된 navigator로 로딩 다이얼로그를 닫습니다.
      if (navigator.mounted) navigator.pop();

      // 미리 저장된 scaffoldMessenger로 오류 메시지를 표시합니다.
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('계정 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis, // 공간이 부족하면 ... 처리
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onAdd,
          tooltip: '추가하기',
        ),
      ],
    );
  }

  // 자녀 목록
  Widget _buildChildList(BuildContext context, DataRepository firestoreService) {
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
                  onConfirm: () async {
                    try {
                      // 1. 알림 서비스 가져오기
                      final notificationService = Provider.of<NotificationService>(context, listen: false);

                      // 2. 현재 저장된 모든 스케줄 가져오기 (Stream의 최신 값)
                      // 주의: snapshot.data를 사용하면 자녀 목록이므로 안됨. Repository에서 스케줄을 가져와야 함.
                      final allSchedules = await firestoreService.getAllSchedules().first;

                      // 3. 해당 자녀와 연관된 스케줄 필터링
                      final relatedSchedules = allSchedules.where((s) => s.childId == child.id);

                      // 4. 연관된 알림 모두 취소
                      for (var schedule in relatedSchedules) {
                        await notificationService.cancelNotificationsForSchedule(schedule);
                      }

                      // 5. 데이터 삭제 (자녀 및 연관 스케줄 DB 삭제)
                      await firestoreService.deleteChild(child.id);
                    } catch (e) {
                      logger.e('자녀 삭제 중 오류 발생: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('삭제 중 오류가 발생했습니다.')),
                        );
                      }
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 기관 목록
  Widget _buildInstitutionList(BuildContext context, DataRepository firestoreService) {
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formattedContact.isNotEmpty) Text(formattedContact),
                    if (inst.memo.isNotEmpty)
                      Text(
                        inst.memo,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                // onTap으로 수정 다이얼로그
                onTap: () {
                  _showAddEditInstitutionDialog(context, firestoreService, institutionToEdit : inst);
                },
                // 길게 눌러 삭제
                onLongPress: () => _showDeleteConfirmation(
                  context,
                  title: '기관 삭제',
                  content: '${inst.name} 기관을 삭제하시겠습니까? (연결된 일정이 있다면 함께 정리해주세요)',
                  onConfirm: () async {
                    try {
                      // 1. 알림 서비스 가져오기
                      final notificationService = Provider.of<NotificationService>(context, listen: false);

                      // 2. 현재 저장된 모든 스케줄 가져오기
                      final allSchedules = await firestoreService.getAllSchedules().first;

                      // 3. 해당 기관과 연관된 스케줄 필터링
                      final relatedSchedules = allSchedules.where((s) => s.institutionId == inst.id);

                      // 4. 연관된 알림 모두 취소
                      for (var schedule in relatedSchedules) {
                        await notificationService.cancelNotificationsForSchedule(schedule);
                      }

                      // 5. 데이터 삭제 (기관 및 연관 스케줄 DB 삭제)
                      await firestoreService.deleteInstitution(inst.id);
                    } catch (e) {
                      logger.e('기관 삭제 중 오류 발생: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('삭제 중 오류가 발생했습니다.')),
                        );
                      }
                    }
                  },
                ),
                // 전화 걸기 아이콘 버튼
                trailing: inst.contactNumber.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.phone),
                        // ListTile의 onTap과 분리되어 아이콘만 독립적으로 동작
                        onPressed: () => _makePhoneCall(context, inst.contactNumber),
                        tooltip: '전화 걸기',
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
  void _showAddEditChildDialog(BuildContext context, DataRepository firestoreService, {Child? childToEdit}) {
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
                    await firestoreService.addChild(name);
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
  void _showAddEditInstitutionDialog(BuildContext context, DataRepository firestoreService, {Institution? institutionToEdit}) {
    final formKey = GlobalKey<FormState>();
    final bool isEditing = institutionToEdit != null;
    final nameController = TextEditingController(text: institutionToEdit?.name ?? '');
    final contactController = TextEditingController(text: institutionToEdit != null ? _formatPhoneNumber(institutionToEdit.contactNumber) : '');
    final memoController = TextEditingController(text: institutionToEdit?.memo);

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
                // 메모 필드
                TextFormField(
                  controller: memoController,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택 사항)',
                    hintText: '예: 담당 선생님 성함, 셔틀 기사님 번호 등',
                  ),
                  // maxLines: 1,
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
                  final memo = memoController.text.trim();

                  if (isEditing) {
                    // 수정
                    await firestoreService.updateInstitution(Institution(
                      id: institutionToEdit.id,
                      name: name,
                      contactNumber: contact,
                      memo: memo,
                    ));
                  } else {
                    await firestoreService.addInstitution(name, contact, memo: memo);
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
