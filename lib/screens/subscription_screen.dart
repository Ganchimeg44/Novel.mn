import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedTab = 0;
  _SubscriptionPackage? _selectedPackage;

  bool _loading = true;
  bool _submitting = false;

  String? _errorMessage;

  String _sixDigitId = '';
  int _vipDays = 0;
  int _vvipDays = 0;

  static const List<_SubscriptionPackage> _vipPackages = [
    _SubscriptionPackage(
      label: '1 сар',
      months: 1,
      days: 30,
      price: 5000,
    ),
    _SubscriptionPackage(
      label: '2 сар',
      months: 2,
      days: 60,
      price: 13000,
    ),
    _SubscriptionPackage(
      label: '3 сар',
      months: 3,
      days: 90,
      price: 27000,
    ),
    _SubscriptionPackage(
      label: '1 жил',
      months: 12,
      days: 365,
      price: 50000,
    ),
  ];

  static const List<_SubscriptionPackage> _vvipPackages = [
    _SubscriptionPackage(
      label: '1 сар',
      months: 1,
      days: 30,
      price: 7000,
    ),
    _SubscriptionPackage(
      label: '2 сар',
      months: 2,
      days: 60,
      price: 19000,
    ),
    _SubscriptionPackage(
      label: '3 сар',
      months: 3,
      days: 90,
      price: 37000,
    ),
    _SubscriptionPackage(
      label: '1 жил',
      months: 12,
      days: 365,
      price: 70000,
    ),
  ];

  List<_SubscriptionPackage> get _currentPackages {
    return _selectedTab == 0 ? _vipPackages : _vvipPackages;
  }

  String get _selectedType {
    return _selectedTab == 0 ? 'VIP' : 'VVIP';
  }

  String get _selectedEntitlementType {
    return _selectedTab == 0 ? 'vip' : 'vvip';
  }

  int get _currentDays {
    return _selectedTab == 0 ? _vipDays : _vvipDays;
  }

  Color get _currentAccent {
    return _selectedTab == 0
        ? AppColors.vipAccent
        : AppColors.vvipAccent;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Нэвтэрсэн хэрэглэгч олдсонгүй.';
      });
      return;
    }

    try {
      final document = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!document.exists) {
        setState(() {
          _loading = false;
          _errorMessage = 'Хэрэглэгчийн мэдээлэл олдсонгүй.';
        });
        return;
      }

      final data = document.data() ?? <String, dynamic>{};

      setState(() {
        _sixDigitId = (data['sixDigitId'] ?? '').toString();
        _vipDays = _readInt(data['vipDays']);
        _vvipDays = _readInt(data['vvipDays']);
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Мэдээлэл унших үед алдаа гарлаа: $error';
      });
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(text[i]);
    }

    return '${buffer.toString()}₮';
  }

  void _changeTab(int index) {
    setState(() {
      _selectedTab = index;
      _selectedPackage = null;
    });
  }

  Future<void> _copyId() async {
    if (_sixDigitId.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: _sixDigitId),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('6 оронтой ID хуулагдлаа.'),
      ),
    );
  }

  Future<void> _createPaymentRequest() async {
    final firebaseUser = _auth.currentUser;
    final package = _selectedPackage;

    if (firebaseUser == null) {
      _showMessage('Нэвтэрсэн хэрэглэгч олдсонгүй.');
      return;
    }

    if (package == null) {
      _showMessage('Эхлээд багцаа сонгоно уу.');
      return;
    }

    if (_sixDigitId.isEmpty) {
      _showMessage('Таны 6 оронтой ID олдсонгүй.');
      return;
    }

    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      final request =
          _firestore.collection('paymentRequests').doc();

      await request.set({
        'requestId': request.id,
        'userUid': firebaseUser.uid,
        'sixDigitId': _sixDigitId,

        'entitlementType': _selectedEntitlementType,

        'planLabel': package.label,
        'months': package.months,
        'days': package.days,
        'amount': package.price,

        'status': 'pending',

        'approvedAt': null,
        'approvedBy': null,

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await _showSuccessDialog(package);

      if (!mounted) return;

      setState(() {
        _selectedPackage = null;
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Төлбөрийн хүсэлт үүсгэхэд алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showSuccessDialog(
    _SubscriptionPackage package,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: AppColors.gold,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Хүсэлт илгээгдлээ'),
              ),
            ],
          ),
          content: Text(
            '${package.label} $_selectedType эрхийн '
            '${_formatMoney(package.price)} төлбөрийн хүсэлт үүслээ.\n\n'
            'Админ гүйлгээг шалгаж баталсны дараа '
            '${package.days} хоног таны эрх дээр нэмэгдэнэ.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Ойлголоо'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Эрх авах'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.body(),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });

                _loadUser();
              },
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 760,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.xxl),
              _buildTabs(),
              const SizedBox(height: AppSpacing.xl),
              _buildCurrentBalance(),
              const SizedBox(height: AppSpacing.lg),
              _buildAccessDescription(),
              const SizedBox(height: AppSpacing.xxl),
              _buildPackages(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Novel.mn',
          style: AppTypography.appLogo(),
        ),
        const SizedBox(height: 4),
        Text(
          'Унших эрхээ сонгоно уу',
          style: AppTypography.body(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          AppRadius.button,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SubscriptionTab(
              title: 'VIP',
              selected: _selectedTab == 0,
              onTap: () => _changeTab(0),
            ),
          ),
          Expanded(
            child: _SubscriptionTab(
              title: 'VVIP',
              selected: _selectedTab == 1,
              onTap: () => _changeTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance() {
    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _currentAccent.withValues(
                alpha: 0.14,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _selectedTab == 0
                  ? Icons.workspace_premium_rounded
                  : Icons.diamond_rounded,
              color: _currentAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedType эрх',
                  style: AppTypography.cardTitle(),
                ),
                const SizedBox(height: 3),
                Text(
                  'Одоогийн үлдэгдэл',
                  style: AppTypography.meta(),
                ),
              ],
            ),
          ),
          Text(
            '$_currentDays хоног',
            style: GoogleFonts.poppins(
              color: _currentAccent,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDescription() {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _selectedTab == 0
                ? Icons.auto_stories_rounded
                : Icons.diamond_rounded,
            color: _currentAccent,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _selectedTab == 0
                  ? 'VIP эрхээр +18-аас бусад premium зохиол, '
                      'бүлгүүдийг унших боломжтой.'
                  : 'VVIP эрхээр VIP-ийн бүх контент орно. '
                      'Мөн 18 нас хүрсэн хэрэглэгч +18 контентыг '
                      'үзэж, унших боломжтой.',
              style: AppTypography.body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_selectedType багц сонгох',
          style: AppTypography.sectionTitle(),
        ),
        const SizedBox(height: AppSpacing.md),

        ..._currentPackages.map(
          (package) {
            final selected =
                _selectedPackage == package;

            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
              ),
              child: _PackageCard(
                package: package,
                selected: selected,
                accent: _currentAccent,
                moneyFormatter: _formatMoney,
                onTap: () {
                  setState(() {
                    _selectedPackage = package;
                  });
                },
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        _buildPaymentReference(),

        const SizedBox(height: AppSpacing.lg),

        _buildPaymentSummary(),

        const SizedBox(height: AppSpacing.lg),

        ElevatedButton.icon(
          onPressed:
              _selectedPackage == null || _submitting
                  ? null
                  : _createPaymentRequest,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.check_circle_outline_rounded,
                ),
          label: Text(
            _submitting
                ? 'Илгээж байна...'
                : 'Төлбөр төлсөн',
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          'Товчийг зөвхөн банкны шилжүүлгээ хийсний дараа дарна уу. '
          'Гүйлгээний утга дээр өөрийн 6 оронтой ID-г бичнэ.',
          textAlign: TextAlign.center,
          style: AppTypography.meta(),
        ),
      ],
    );
  }

  Widget _buildPaymentReference() {
    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Гүйлгээний утга',
            style: AppTypography.cardTitle(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Банкны шилжүүлгийн утга дээр зөвхөн '
            'өөрийн 6 оронтой ID-г бичнэ.',
            style: AppTypography.body(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(
                AppRadius.input,
              ),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _sixDigitId.isEmpty
                        ? 'ID олдсонгүй'
                        : _sixDigitId,
                    style: GoogleFonts.poppins(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _sixDigitId.isEmpty
                          ? null
                          : _copyId,
                  tooltip: 'ID хуулах',
                  icon: const Icon(
                    Icons.copy_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final package = _selectedPackage;

    if (package == null) {
      return Container(
        padding: const EdgeInsets.all(
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(
            AppRadius.card,
          ),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Text(
          'Дээрээс багцаа сонгоно уу.',
          textAlign: TextAlign.center,
          style: AppTypography.body(),
        ),
      );
    }

    return PremiumCard(
      child: Column(
        children: [
          _SummaryRow(
            label: 'Эрх',
            value: _selectedType,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Багц',
            value: package.label,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Нэмэгдэх хоног',
            value: '${package.days} хоног',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Одоогийн үлдэгдэл',
            value: '$_currentDays хоног',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.md,
            ),
            child: Divider(
              color: AppColors.border,
              height: 1,
            ),
          ),
          _SummaryRow(
            label: 'Батлагдсаны дараа',
            value:
                '${_currentDays + package.days} хоног',
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            label: 'Төлөх дүн',
            value: _formatMoney(package.price),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPackage {
  final String label;
  final int months;
  final int days;
  final int price;

  const _SubscriptionPackage({
    required this.label,
    required this.months,
    required this.days,
    required this.price,
  });
}

class _SubscriptionTab extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SubscriptionTab({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: selected
                ? Colors.white
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final _SubscriptionPackage package;
  final bool selected;
  final Color accent;
  final String Function(int) moneyFormatter;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.selected,
    required this.accent,
    required this.moneyFormatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppRadius.card,
        ),
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(
              AppRadius.card,
            ),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  selected
                      ? Icons.check_rounded
                      : Icons.workspace_premium_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.label,
                      style:
                          AppTypography.cardTitle(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${package.days} хоног',
                      style: AppTypography.meta(),
                    ),
                  ],
                ),
              ),
              Text(
                moneyFormatter(package.price),
                style: GoogleFonts.poppins(
                  color: selected
                      ? accent
                      : AppColors.goldLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: highlight
                ? AppColors.goldLight
                : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: highlight
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}