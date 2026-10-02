import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ExpenseFloatingMenu extends StatefulWidget {
  final Future<void> Function() onManualEntry;
  final Future<void> Function() onGallery;
  final Future<void> Function() onCamera;

  const ExpenseFloatingMenu({
    super.key,
    required this.onManualEntry,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  State<ExpenseFloatingMenu> createState() => _ExpenseFloatingMenuState();
}

class _ExpenseFloatingMenuState extends State<ExpenseFloatingMenu> {
  bool _isOpen = false;

  Widget _action(
    String label,
    IconData icon,
    Offset offset,
    Future<void> Function() callback,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      right: _isOpen ? offset.dx : 0,
      bottom: _isOpen ? offset.dy : 0,
      child: IgnorePointer(
        ignoring: !_isOpen,
        child: AnimatedOpacity(
          opacity: _isOpen ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: FloatingActionButton.small(
            heroTag: label,
            tooltip: label,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: AppColors.teal,
            onPressed: () async {
              setState(() => _isOpen = false);
              await callback();
            },
            child: Icon(icon),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        children: [
          _action(
            'Catat Manual',
            Icons.edit_note_rounded,
            const Offset(112, 4),
            widget.onManualEntry,
          ),
          _action(
            'Unggah dari Galeri',
            Icons.add_photo_alternate_rounded,
            const Offset(82, 82),
            widget.onGallery,
          ),
          _action(
            'Foto Struk',
            Icons.camera_alt_outlined,
            const Offset(4, 112),
            widget.onCamera,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'expense-menu',
              tooltip: _isOpen ? 'Tutup menu pengeluaran' : 'Catat Pengeluaran',
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              onPressed: () => setState(() => _isOpen = !_isOpen),
              child: AnimatedRotation(
                turns: _isOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
