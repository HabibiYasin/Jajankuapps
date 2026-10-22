import 'dart:async';

import 'package:flutter/material.dart';

import '../models/transaction_model.dart';

enum ManualTourStep {
  add,
  menu,
  filling,
  save,
  today,
  download,
  progressBack,
  history,
  transaction,
  edit,
  editing,
  saveEdit,
  delete,
}

/// Coordinates coach marks on the real application widgets.
class ManualTour extends ChangeNotifier {
  ManualTour._();
  static final instance = ManualTour._();
  VoidCallback? onStart;
  ManualTourStep? step;
  TransactionModel? example;
  bool get active => step != null;
  final _keys = <String, GlobalKey>{};
  GlobalKey key(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey(debugLabel: 'tour-$name'));
  OverlayEntry? _overlay;
  NavigatorState? _navigator;
  Timer? _timer;
  int _generation = 0;
  String? _scrolledTarget;
  String? _fieldTarget;
  String get target =>
      _fieldTarget ??
      switch (step) {
        ManualTourStep.add => 'add',
        ManualTourStep.menu => 'manual',
        ManualTourStep.filling => 'merchant',
        ManualTourStep.save => 'save',
        ManualTourStep.today => 'today',
        ManualTourStep.download => 'download',
        ManualTourStep.progressBack => 'progressBack',
        ManualTourStep.history => 'history',
        ManualTourStep.transaction => 'transaction',
        ManualTourStep.edit => 'edit',
        ManualTourStep.editing => 'editName',
        ManualTourStep.saveEdit => 'saveEdit',
        ManualTourStep.delete => 'delete',
        null => '',
      };
  String get message => switch (step) {
    ManualTourStep.add => 'Ketuk tombol + untuk menambah pengeluaran.',
    ManualTourStep.menu => 'Kamera untuk foto struk. Galeri untuk bukti yang sudah tersimpan. Ikon pensil untuk menulis manual. Ketuk ikon pensil.',
    ManualTourStep.filling => 'Perhatikan contoh diisi perlahan pada form ini. Catatan contoh tidak masuk ke data keuanganmu.',
    ManualTourStep.save => 'Periksa nama, nominal, kategori, metode pembayaran, sumber uang, dan tanggal. Ketuk Simpan Pengeluaran.',
    ManualTourStep.today => 'Catatan contoh sudah disimpan. Ketuk Hari Ini untuk melihat progres pengeluaranmu.',
    ManualTourStep.download => 'Progres ini bisa kamu bagikan lewat tombol Bagikan. Sekarang coba ketuk Unduh untuk menyimpan gambarnya ke galeri. Izinkan akses foto jika diminta.',
    ManualTourStep.progressBack => 'Gambar tersimpan! Ketuk tombol kembali untuk menuju Dashboard, lalu kita lanjut ke Riwayat.',
    ManualTourStep.history => 'Sekarang ketuk tab Riwayat.',
    ManualTourStep.transaction =>
      'Ketuk catatan contoh yang baru saja disimpan.',
    ManualTourStep.edit =>
      'Ketuk Edit Detail untuk mengubah informasi pengeluaran.',
    ManualTourStep.editing =>
      'Perhatikan nama dan sumber uang diubah perlahan.',
    ManualTourStep.saveEdit => 'Ketuk Simpan untuk menyimpan perubahan.',
    ManualTourStep.delete => 'Untuk menghapus catatan, ketuk Hapus Riwayat Ini. Yang dihapus hanya catatan contoh ini.',
    null => '',
  };

  void start(BuildContext context) {
    stop();
    _navigator = Navigator.of(context);
    _navigator!.popUntil((route) => route.isFirst);
    onStart?.call();
    step = ManualTourStep.add;
    _overlay = OverlayEntry(builder: (_) => _TourOverlay(tour: this));
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _overlay?.markNeedsBuild();
      final targetContext = key(target).currentContext;
      if (targetContext != null && _scrolledTarget != target) {
        _scrolledTarget = target;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
    notifyListeners();
  }

  void go(ManualTourStep next) {
    if (!active) return;
    _fieldTarget = null;
    step = next;
    _scrolledTarget = null;
    _overlay?.markNeedsBuild();
    notifyListeners();
  }

  void focusField(String name) {
    _fieldTarget = name;
    _scrolledTarget = null;
    _overlay?.markNeedsBuild();
  }

  void cancel() {
    final navigator = _navigator;
    stop();
    if (navigator != null && navigator.mounted) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    _fieldTarget = null;
    step = null;
    example = null;
    _scrolledTarget = null;
    notifyListeners();
  }

  Future<bool> type(
    TextEditingController controller,
    String text,
    bool Function() alive,
  ) async {
    final generation = _generation;
    if (!active || !alive()) return false;
    controller.clear();
    for (var i = 1; i <= text.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!active || generation != _generation || !alive()) return false;
      controller.text = text.substring(0, i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return active && generation == _generation && alive();
  }
}

class _TourOverlay extends StatelessWidget {
  const _TourOverlay({required this.tour});
  final ManualTour tour;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final render = tour.key(tour.target).currentContext?.findRenderObject();
    Rect? rect;
    if (render is RenderBox && render.attached && render.hasSize) {
      rect = (render.localToGlobal(Offset.zero) & render.size)
          .inflate(5)
          .intersect(Offset.zero & size);
    }
    final hole = rect != null && !rect.isEmpty
        ? rect
        : Rect.fromLTWH(0, size.height / 2, 0, 0);
    Widget shade(Rect r) => Positioned.fromRect(
      rect: r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.52)),
      ),
    );
    final typing =
        tour.step == ManualTourStep.filling ||
        tour.step == ManualTourStep.editing;
    return Stack(
      children: [
        shade(Rect.fromLTRB(0, 0, size.width, hole.top)),
        shade(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
        shade(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
        shade(Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom)),
        if (typing)
          Positioned.fromRect(
            rect: hole,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),
        if (!hole.isEmpty)
          Positioned.fromRect(
            rect: hole,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.tealAccent, width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          top: hole.center.dy > size.height / 2 ? safe.top + 16 : null,
          bottom: hole.center.dy <= size.height / 2 ? safe.bottom + 16 : null,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(child: Text(tour.message)),
                  IconButton(
                    tooltip: 'Akhiri tutorial',
                    onPressed: tour.cancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
