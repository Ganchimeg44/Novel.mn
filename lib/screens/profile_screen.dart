import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'admin_screen.dart';
import 'subscription_screen.dart';
import 'xp_redeem_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

bool _sendingBirthdayGiftRequest = false;

  late Future<UserModel?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<UserModel?> _loadUser() {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      return Future.value(null);
    }

    return _userRepository.getUserByUid(uid);
  }

  Future<void> _copySixDigitId(String sixDigitId) async {
    await Clipboard.setData(
      ClipboardData(text: sixDigitId),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID хуулагдлаа'),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _changeAvatar(UserModel user) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Профайл зураг сонгох', style: AppTypography.sectionTitle()),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _ProfileAvatarChoice(label: 'Эрэгтэй', icon: Icons.man_rounded, selected: user.avatarType == 'male', onTap: () => Navigator.pop(context, 'male'))),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _ProfileAvatarChoice(label: 'Эмэгтэй', icon: Icons.woman_rounded, selected: user.avatarType == 'female', onTap: () => Navigator.pop(context, 'female'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || selected == user.avatarType) return;
    await _userRepository.updateMutableProfileFields(user.uid, {'avatarType': selected});
    if (!mounted) return;
    setState(() => _userFuture = _loadUser());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профайл зураг шинэчлэгдлээ.')));
  }

  Future<void> _logout() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }
Future<void> _requestBirthdayGift(UserModel user) async {
  if (_sendingBirthdayGiftRequest) {
    return;
  }

  final firebaseUser = _authService.currentUser;

  if (firebaseUser == null) {
    return;
  }

  final birthDate = user.birthDate;

  if (birthDate == null) {
    return;
  }

  final now = DateTime.now();

  final isBirthdayToday =
      now.month == birthDate.month &&
      now.day == birthDate.day;

  if (!isBirthdayToday) {
    _showBirthdayMessage(
      'Төрсөн өдрийн бэлгийг зөвхөн төрсөн өдрөөрөө авах боломжтой.',
    );
    return;
  }

  if (user.birthdayGiftClaimedYear == now.year) {
    _showBirthdayMessage(
      'Та энэ жилийн төрсөн өдрийн бэлгээ аль хэдийн авсан байна.',
    );
    return;
  }

  setState(() {
    _sendingBirthdayGiftRequest = true;
  });

  try {
    // Firestore-оос хамгийн сүүлийн user мэдээллийг дахин шалгана.
    final userSnapshot = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!userSnapshot.exists) {
      throw Exception(
        'Хэрэглэгчийн мэдээлэл олдсонгүй.',
      );
    }

    final latestData =
        userSnapshot.data() ?? <String, dynamic>{};

    final latestClaimedYear =
        latestData['birthdayGiftClaimedYear'];

    if (latestClaimedYear == now.year) {
      throw Exception(
        'Энэ жилийн төрсөн өдрийн бэлгийг аль хэдийн авсан байна.',
      );
    }

    // Тухайн жилийн pending хүсэлт байгаа эсэхийг шалгана.
    final existingRequests = await _firestore
        .collection('birthdayGiftRequests')
        .where(
          'userUid',
          isEqualTo: firebaseUser.uid,
        )
        .where(
          'status',
          isEqualTo: 'pending',
        )
        .get();

    final alreadyPendingThisYear =
        existingRequests.docs.any(
      (document) {
        final data = document.data();

        return _readBirthdayYear(
              data['year'],
            ) ==
            now.year;
      },
    );

    if (alreadyPendingThisYear) {
      throw Exception(
        'Таны төрсөн өдрийн бэлгийн хүсэлт аль хэдийн хүлээгдэж байна.',
      );
    }

    await _firestore
        .collection('birthdayGiftRequests')
        .add(
      {
        'userUid': firebaseUser.uid,
        'sixDigitId': user.sixDigitId,
        'entitlementType': 'vip',
        'days': 7,
        'year': now.year,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
      },
    );

    if (!mounted) return;

    _showBirthdayMessage(
      '🎂 VIP +7 хоногийн хүсэлт амжилттай илгээгдлээ.',
    );
  } catch (error) {
    if (!mounted) return;

    _showBirthdayMessage(
      'Хүсэлт илгээх үед алдаа гарлаа: $error',
    );
  } finally {
    if (mounted) {
      setState(() {
        _sendingBirthdayGiftRequest = false;
      });
    }
  }
}

int _readBirthdayYear(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

void _showBirthdayMessage(String message) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Профайл',
          style: AppTypography.pageTitle(
            color: AppColors.textPrimary,
          ).copyWith(
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            final user = snapshot.data;

            if (user == null) {
              return Center(
                child: Text(
                  'Хэрэглэгчийн мэдээлэл олдсонгүй.',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.profileMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppSpacing.xl,
                  ),
                  children: [
                    _buildHeader(user),

                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),

                    Text(
                      'Эрхүүд',
                      style: AppTypography.sectionTitle(),
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    _buildMembershipRow(user),

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SubscriptionScreen(),
                            ),
                          );

                          if (!mounted) return;

                          setState(() {
                            _userFuture = _loadUser();
                          });
                        },
                        icon: const Icon(
                          Icons.workspace_premium_rounded,
                        ),
                        label: const Text(
                          'Эрх авах',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),

                    _buildXpCard(user),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const XpRedeemScreen(),
                            ),
                          );

                          if (!mounted) return;

                          setState(() {
                            _userFuture = _loadUser();
                          });
                        },
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                        ),
                        label: const Text(
                          'XP-гээ эрхийн хоногоор солих',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: AppSpacing.lg,
                    ),

                    _buildBirthdayCard(user),

                    if (user.isAdmin) ...[
                      const SizedBox(
                        height: AppSpacing.xxl,
                      ),

                      Text(
                        'Админ',
                        style: AppTypography.sectionTitle(),
                      ),

                      const SizedBox(
                        height: AppSpacing.md,
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AdminScreen(),
                              ),
                            );

                            if (!mounted) return;

                            setState(() {
                              _userFuture = _loadUser();
                            });
                          },
                          icon: const Icon(
                            Icons.admin_panel_settings_rounded,
                          ),
                          label: const Text(
                            'Админ хэсэг',
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),

                    Text(
                      'Тохиргоо',
                      style: AppTypography.sectionTitle(),
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    _buildSettingsRows(user),

                    const SizedBox(
                      height: AppSpacing.xxxl,
                    ),

                    _buildLogoutButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _changeAvatar(user),
            child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.gold,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              user.avatarType == 'male'
                  ? Icons.man_rounded
                  : user.avatarType == 'female'
                      ? Icons.woman_rounded
                      : Icons.person_rounded,
              color: AppColors.gold,
              size: 48,
            ),
          ),
          ),

          const SizedBox(
            height: AppSpacing.md,
          ),

          Text(
            user.username,
            style: AppTypography.pageTitle(),
          ),

          const SizedBox(
            height: AppSpacing.sm,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ID: ${user.sixDigitId}',
                style: AppTypography.meta(),
              ),

              const SizedBox(
                width: AppSpacing.xs,
              ),

              GestureDetector(
                onTap: () =>
                    _copySixDigitId(user.sixDigitId),
                child: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.textMuted,
                  size: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipRow(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _MembershipCard(
            label: 'VIP',
            days: user.remainingVipDays,
            icon: Icons.workspace_premium_rounded,
            accent: AppColors.vipAccent,
          ),
        ),
        const SizedBox(
          width: AppSpacing.sm,
        ),
        Expanded(
          child: _MembershipCard(
            label: 'VVIP',
            days: user.remainingVvipDays,
            icon: Icons.diamond_rounded,
            accent: AppColors.vvipAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildXpCard(UserModel user) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.diamond_outlined,
              color: AppColors.primaryLight,
            ),
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.xp} XP',
                  style: AppTypography.cardTitle(),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '10 XP = 1 хоног',
                  style: AppTypography.meta(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildBirthdayCard(UserModel user) {
  final birthDate = user.birthDate;

  if (birthDate == null) {
    return const SizedBox.shrink();
  }

  final now = DateTime.now();

  final isBirthdayToday =
      now.month == birthDate.month &&
      now.day == birthDate.day;

  final alreadyClaimedThisYear =
      user.birthdayGiftClaimedYear == now.year;

  final canClaim =
      isBirthdayToday &&
      !alreadyClaimedThisYear;

  return PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.gold,
              size: 28,
            ),
            const SizedBox(
              width: AppSpacing.md,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Төрсөн өдрийн бэлэг',
                    style: AppTypography.cardTitle(),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    'VIP +7 хоног',
                    style: AppTypography.meta(
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: AppSpacing.md,
        ),

        Text(
          alreadyClaimedThisYear
              ? '🎉 Энэ жилийн бэлгээ авсан байна.'
              : isBirthdayToday
                  ? '🎂 Төрсөн өдрийн мэнд! VIP +7 хоногийн бэлгээ аваарай.'
                  : 'Зөвхөн төрсөн өдрөөрөө идэвхжинэ.',
          style: AppTypography.body(),
        ),

        if (canClaim) ...[
          const SizedBox(
            height: AppSpacing.lg,
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _sendingBirthdayGiftRequest
                      ? null
                      : () =>
                          _requestBirthdayGift(
                            user,
                          ),
              icon: _sendingBirthdayGiftRequest
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .card_giftcard_rounded,
                    ),
              label: Text(
                _sendingBirthdayGiftRequest
                    ? 'Илгээж байна...'
                    : 'VIP +7 хоног авах',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildSettingsRows(UserModel user) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _SettingsRow(
            icon: Icons.menu_book_outlined,
            label: 'Унших тохиргоо',
          ),

          const _SettingsDivider(),

          _SettingsRow(
            icon: Icons.favorite_border_rounded,
            label: 'Дуртай жанр',
            trailingText:
                user.favoriteGenres.isEmpty
                    ? null
                    : user.favoriteGenres.join(', '),
          ),

          const _SettingsDivider(),

          const _SettingsRow(
            icon: Icons.notifications_none_rounded,
            label: 'Мэдэгдэл',
          ),

          const _SettingsDivider(),

          _SettingsRow(
            icon: Icons.palette_outlined,
            label: 'Bookmark өнгө',
            trailingSwatch:
                _parseHexColor(user.bookmarkColor),
          ),

          const _SettingsDivider(),

          _SettingsRow(
            icon: Icons.comment_outlined,
            label: 'Сэтгэгдэл',
            trailingText:
                user.commentsEnabled
                    ? 'Идэвхтэй'
                    : 'Идэвхгүй',
          ),
        ],
      ),
    );
  }

  Color? _parseHexColor(String hex) {
    try {
      final cleaned =
          hex.replaceAll('#', '');

      final fullHex =
          cleaned.length == 6
              ? 'FF$cleaned'
              : cleaned;

      return Color(
        int.parse(
          fullHex,
          radix: 16,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(
            color: AppColors.danger,
          ),
          minimumSize:
              const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              AppRadius.button,
            ),
          ),
        ),
        child: const Text(
          'Гарах',
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final String label;
  final int days;
  final IconData icon;
  final Color accent;

  const _MembershipCard({
    required this.label,
    required this.days,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: accent,
            size: 24,
          ),

          const SizedBox(
            height: AppSpacing.sm,
          ),

          Text(
            label,
            style: AppTypography.meta(
              color: accent,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            '$days хоног',
            style: AppTypography.cardTitle(),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final Color? trailingSwatch;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailingText,
    this.trailingSwatch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                color: AppColors.textPrimary,
              ),
            ),
          ),

          if (trailingText != null)
            Text(
              trailingText!,
              style: AppTypography.meta(),
            ),

          if (trailingSwatch != null) ...[
            const SizedBox(
              width: AppSpacing.sm,
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: trailingSwatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
            ),
          ],

          const SizedBox(
            width: AppSpacing.sm,
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: AppColors.border,
    );
  }
}

class _ProfileAvatarChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileAvatarChoice({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primaryLight : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 52, color: selected ? AppColors.primaryLight : AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: AppTypography.body(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
