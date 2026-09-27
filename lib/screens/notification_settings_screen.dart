import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _working = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled =
          await NotificationService.instance.isEnabled();

      if (!mounted) return;

      setState(() {
        _enabled = enabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _changeEnabled(bool value) async {
    if (_working) return;

    setState(() {
      _working = true;
    });

    try {
      if (value) {
        final enabled = await NotificationService
            .instance
            .enableNotifications();

        if (!mounted) return;

        setState(() {
          _enabled = enabled;
        });

        if (!enabled) {
          _showMessage(
            'Мэдэгдлийн зөвшөөрөл өгөөгүй байна.',
          );
        }
      } else {
        await NotificationService.instance
            .disableNotifications();

        if (!mounted) return;

        setState(() {
          _enabled = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('NOTIFICATION ERROR: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage(
        'Мэдэгдлийн тохиргоог өөрчилж чадсангүй: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  void _showMessage(String message) {
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
        title: const Text('Мэдэгдэл'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Push мэдэгдэл',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _enabled
                                  ? 'Шинэ бүлгийн мэдэгдэл хүлээн авна.'
                                  : 'Мэдэгдэл унтраалттай байна.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        onChanged:
                            _working
                                ? null
                                : _changeEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Та дуртай болгосон зохиолын шинэ бүлэг '
                  'нийтлэгдэхэд мэдэгдэл хүлээн авна.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
    );
  }
}
