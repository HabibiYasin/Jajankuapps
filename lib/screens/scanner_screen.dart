import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  final Future<void> Function() onProcessImage;
  final Future<void> Function() onTakePhoto;
  final Future<void> Function() onManualEntry;
  final File? imageFile;
  final String rawTextDebug;

  const ScannerScreen({
    super.key,
    required this.onProcessImage,
    required this.onTakePhoto,
    required this.onManualEntry,
    required this.imageFile,
    required this.rawTextDebug,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Catat Pengeluaran',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Pilih cara mencatat pengeluaranmu.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('1. Catat Manual'),
            onPressed: widget.onManualEntry,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('2. Unggah Screenshot dari Galeri'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: widget.onProcessImage,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('3. Foto Struk'),
            onPressed: widget.onTakePhoto,
          ),
          const SizedBox(height: 8),
          const Text(
            'Gambar galeri dan foto akan dibaca otomatis untuk mencatat pengeluaran.',
            style: TextStyle(color: AppColors.charcoal, fontSize: 12),
          ),
          const SizedBox(height: 20),

          if (widget.imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                widget.imageFile!,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // --- HANYA SATU KOTAK DEBUG TEXT MENTAH OCR ---
            const Row(
              children: [
                Icon(Icons.bug_report, size: 16, color: Colors.orange),
                SizedBox(width: 6),
                Text(
                  'Raw Text OCR (Debug):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: SelectableText(
                widget.rawTextDebug.isEmpty
                    ? "Belum ada teks atau proses gagal."
                    : widget.rawTextDebug,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.greenAccent,
                ),
              ),
            ),
            // ---------------------------------------------
          ] else ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.aqua.withValues(alpha: 0.18),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.aqua.withValues(alpha: 0.7),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 52,
                      color: AppColors.teal,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada gambar yang dipilih',
                      style: TextStyle(color: AppColors.charcoal),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
