import 'dart:io';
import 'package:flutter/material.dart';

class ScannerScreen extends StatelessWidget {
  final VoidCallback onProcessImage;
  final File? imageFile;

  const ScannerScreen({super.key, required this.onProcessImage, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.teal),
            const SizedBox(height: 24),
            const Text('Upload Screenshot Bukti Transfer\nQRIS / Dompet Digital', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: onProcessImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pilih dari Galeri', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (imageFile != null) ...[
              const SizedBox(height: 24),
              const Text('Gambar terakhir diproses:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(imageFile!, height: 200, fit: BoxFit.cover)),
            ]
          ],
        ),
      ),
    );
  }
}