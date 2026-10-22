import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/manual_tour.dart';

class ExpenseFloatingMenu extends StatefulWidget {
  final Future<void> Function()? onIncomeEntry;
  final Future<void> Function() onManualEntry;
  final Future<void> Function() onGallery;
  final Future<void> Function() onCamera;

  const ExpenseFloatingMenu({
    super.key,
    this.onIncomeEntry,
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
    final colors = Theme.of(context).colorScheme;
    final caption = switch (label) {
      'Catat Manual' => 'Tulis',
      'Unggah dari Galeri' => 'Galeri',
      'Foto Struk' => 'Kamera',
      _ => 'Masuk',
    };
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  caption,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FloatingActionButton.small(
                key: label == 'Catat Manual'
                    ? ManualTour.instance.key('manual')
                    : null,
                heroTag: label,
                tooltip: label,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                elevation: 5,
                onPressed: () async {
                  setState(() => _isOpen = false);
                  await callback();
                },
                child: Icon(icon),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: widget.onIncomeEntry == null ? 220 : 305,
      child: Stack(
        children: [
          if (widget.onIncomeEntry != null)
            _action(
              'Catat Pemasukan',
              Icons.add_card_rounded,
              const Offset(0, 220),
              widget.onIncomeEntry!,
            ),
          _action(
            'Catat Manual',
            Icons.edit_note_rounded,
            const Offset(140, 4),
            widget.onManualEntry,
          ),
          _action(
            'Unggah dari Galeri',
            Icons.add_photo_alternate_rounded,
            const Offset(86, 86),
            widget.onGallery,
          ),
          _action(
            'Foto Struk',
            Icons.camera_alt_outlined,
            const Offset(0, 134),
            widget.onCamera,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              key: ManualTour.instance.key('add'),
              heroTag: 'expense-menu',
              tooltip: _isOpen ? 'Tutup menu pengeluaran' : 'Catat Pengeluaran',
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() => _isOpen = !_isOpen);
                if (ManualTour.instance.active) {
                  ManualTour.instance.go(
                    _isOpen ? ManualTourStep.menu : ManualTourStep.add,
                  );
                }
              },
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
