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
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF153F46), Color(0xFF198487)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFADF0DD),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'MULAI DARI SINI',
                              style: TextStyle(
                                color: Color(0xFFADF0DD),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Catat lebih mudah.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pilih cara belajarmu.\nKami bantu langkah demi langkah.',
                        style: TextStyle(
                          color: Color(0xFFD7EBEA),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TutorialChoice(
                        icon: Icons.edit_note_rounded,
                        accent: const Color(0xFF198487),
                        badge: 'PANDUAN LANGSUNG',
                        title: 'Cara tambah manual',
                        description: 'Ikuti sorotan di aplikasi untuk tambah, edit, dan hapus catatan.',
                        action: 'Coba langsung',
                        onTap: () => Navigator.pop(dialogContext, true),
                      ),
                      const SizedBox(height: 14),
                      _TutorialChoice(
                        icon: Icons.play_arrow_rounded,
                        accent: const Color(0xFFB82D79),
                        badge: 'TUTORIAL VIDEO',
                        title: 'Cara tambah otomatis',
                        description: 'Lihat cara mencatat pengeluaran dari foto bukti pembayaran.',
                        action: 'Tonton video',
                        onTap: () => Navigator.pop(dialogContext, false),
                      ),
                      if (allowHideToday) ...[
                        const SizedBox(height: 20),
                        Divider(height: 1, color: colors.outlineVariant),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'tutorial_hidden_date_$uid',
                                  DateTime.now().toIso8601String(),
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('Matikan hari ini'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: colors.onSurfaceVariant,
                              ),
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'tutorial_disabled_$uid',
                                  true,
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('Matikan selamanya'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Bisa dibuka lagi lewat Cara Pakai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
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

class _TutorialChoice extends StatelessWidget {
  const _TutorialChoice({
    required this.icon,
    required this.accent,
    required this.badge,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String badge;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlight = dark ? Color.lerp(accent, Colors.white, 0.45)! : accent;
    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: dark ? 0.15 : 0.055),
        colors.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: highlight.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: highlight.withValues(alpha: 0.15),
        hoverColor: highlight.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: highlight,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        color: highlight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: highlight, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
