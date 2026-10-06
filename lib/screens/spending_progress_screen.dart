import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spending_progress.dart';
import '../services/spending_card_renderer.dart';
import '../services/auth_service.dart';

class SpendingProgressScreen extends StatefulWidget {
  final SpendingProgress progress;
  const SpendingProgressScreen({super.key, required this.progress});
  @override
  State<SpendingProgressScreen> createState() => _SpendingProgressScreenState();
}

class _SpendingProgressScreenState extends State<SpendingProgressScreen> {
  late Future<Uint8List> _image;
  bool _busy = false;
  bool _hideAmounts = false;
  int _messageVariant = Random().nextInt(5);
  @override
  void initState() {
    super.initState();
    _image = _renderImage();
  }

  Future<Uint8List> _renderImage() async {
    final hideAmounts = _hideAmounts;
    final messageVariant = _messageVariant;
    final user = AuthService.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(
      user == null ? 'guest_profile_name' : 'profile_name_${user.uid}',
    );
    final name = [
      user?.displayName,
      savedName,
      'Jajaners',
    ].whereType<String>().firstWhere((value) => value.trim().isNotEmpty).trim();
    return SpendingCardRenderer.render(
      widget.progress,
      username: name,
      messageVariant: messageVariant,
      hideAmounts: hideAmounts,
    );
  }

  Future<void> _export(Uint8List bytes, {required bool share}) async {
    setState(() => _busy = true);
    final name =
        'jajanku_${widget.progress.monthly ? 'bulanan' : 'harian'}_${widget.progress.date.toIso8601String().substring(0, 10)}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      if (share) {
        final renderBox = context.findRenderObject() as RenderBox;
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: '$name.png')],
          fileNameOverrides: ['$name.png'],
          text: '${widget.progress.period}: ${widget.progress.title} — Jajanku',
          sharePositionOrigin:
              renderBox.localToGlobal(Offset.zero) & renderBox.size,
        );
      } else {
        if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
          throw StateError('Izinkan akses foto agar gambar bisa disimpan.');
        }
        await Gal.putImageBytes(bytes, name: name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar berhasil disimpan ke galeri.'),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Gagal ${share ? 'membagikan' : 'menyimpan'} gambar. Silakan coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Progres ${widget.progress.period}'),
      foregroundColor: const Color(0xFF105438),
    ),
    body: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                _image = _renderImage();
              }),
              child: const Text('Gagal membuat gambar. Coba lagi'),
            ),
          );
        }
        if (!snapshot.hasData ||
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snapshot.data!;
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _messageVariant = (_messageVariant + 1) % 5;
                              _image = _renderImage();
                            }),
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Ganti pesan'),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _hideAmounts,
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  _hideAmounts = value ?? false;
                                  _image = _renderImage();
                                }),
                        ),
                        const Text('Tutup nominal'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _export(bytes, share: false),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Unduh'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _export(bytes, share: true),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Bagikan'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    ),
  );
}
