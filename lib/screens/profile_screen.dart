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

  Future<void> _logout() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
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
          Container(
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
            child: Text(
              user.username.isNotEmpty
                  ? user.username[0].toUpperCase()
                  : '?',
              style: AppTypography.novelTitle(
                color: AppColors.gold,
                fontSize: 28,
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

    return PremiumCard(
      child: Row(
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
                  'Төрсөн өдрийн бэлэг (+7 хоног)',
                  style: AppTypography.cardTitle(),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  isBirthdayToday
                      ? alreadyClaimedThisYear
                          ? 'Энэ жилийн бэлгээ аль хэдийн авсан байна.'
                          : 'Өнөөдөр таны төрсөн өдөр байна!'
                      : 'Зөвхөн төрсөн өдрөөрөө идэвхжинэ.',
                  style: AppTypography.meta(),
                ),
              ],
            ),
          ),
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