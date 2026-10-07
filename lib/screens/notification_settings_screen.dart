import 'package:flutter/material.dart';

import '../services/budget_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _notificationsEnabled;
  bool? _noonEnabled;
  bool _savingNoon = false;
  bool _savingNotifications = false;
  bool _notificationLoadFailed = false;
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final enabled = await BudgetNotificationService.isEnabled();
      final noonEnabled = await BudgetNotificationService.isNoonEnabled();
      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _noonEnabled = noonEnabled;
          _notificationLoadFailed = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _notificationLoadFailed = true);
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _savingNotifications = true);
    try {
      await BudgetNotificationService.setEnabled(enabled);
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan notifikasi gagal disimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _toggleNoon(bool enabled) async {
    setState(() => _savingNoon = true);
    try {
      await BudgetNotificationService.setNoonEnabled(enabled);
      if (mounted) setState(() => _noonEnabled = enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengingat jam 12 gagal disimpan. Coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNoon = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifikasi')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifikasi persistent'),
                subtitle: const Text(
                  'Tampilkan progres budget harian di panel notifikasi.',
                ),
                value: _notificationsEnabled ?? true,
                onChanged: _notificationsEnabled == null || _savingNotifications
                    ? null
                    : _toggleNotifications,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Pengingat jam 12 siang'),
                subtitle: const Text(
                  'Cek persentase budget terpakai setiap pukul 12.00.',
                ),
                value: _noonEnabled ?? true,
                onChanged: _noonEnabled == null || _savingNoon
                    ? null
                    : _toggleNoon,
              ),
              if (_notificationLoadFailed)
                TextButton(
                  onPressed: _loadNotifications,
                  child: const Text('Coba muat pengaturan notifikasi lagi'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
