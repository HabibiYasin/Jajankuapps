import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/manual_tour.dart';
import '../screens/automatic_tutorial_screen.dart';
import '../services/auth_service.dart';

Future<void> showTutorialDialog(
  BuildContext context, {
  bool allowHideToday = false,
}) async {
  final uid = AuthService.instance.currentUser?.uid ?? 'guest';
  final manual = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mau belajar cara catat?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Cara tambah manual'),
              subtitle: const Text(
                'Panduan langsung menambah, mengedit, dan menghapus',
              ),
              onTap: () => Navigator.pop(dialogContext, true),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Cara tambah otomatis'),
              subtitle: const Text(
                'Tonton video panduan mencatat dari bukti pembayaran',
              ),
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            if (allowHideToday) ...[
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'tutorial_hidden_date_$uid',
                    DateTime.now().toIso8601String(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Matikan hari ini'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('tutorial_disabled_$uid', true);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Matikan selamanya'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (manual == true) {
    ManualTour.instance.start(context);
  } else if (manual == false) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AutomaticTutorialScreen()),
    );
  }
}
