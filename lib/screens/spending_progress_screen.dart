import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spending_progress.dart';
import '../models/spending_card_style.dart';
import '../services/profile_plan_store.dart';
import '../widgets/spending_card_customizer.dart';
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
  SpendingCardCharacter _character = SpendingCardCharacter.jajanku;
  SpendingCardColor? _cardColor;
  String? _vipUid;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<bool>? _planSubscription;

  bool get _isVip =>
      _vipUid != null && _vipUid == AuthService.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _image = _renderImage();
    final auth = AuthService.instance;
    if (auth.isConfigured) {
      _authSubscription = auth.authStateChanges.listen(_watchPlan);
    }
  }

  void _watchPlan(User? user) {
    _planSubscription?.cancel();
    _planSubscription = null;
    _setVip(null);
    if (user == null) return;
    _planSubscription = ProfilePlanStore(FirebaseFirestore.instance)
        .watchVip(user.uid)
        .listen(
          (isVip) {
            if (AuthService.instance.currentUser?.uid != user.uid) return;
            _setVip(isVip ? user.uid : null);
          },
          onError: (Object error) {
            if (AuthService.instance.currentUser?.uid != user.uid) return;
            _setVip(null);
            debugPrint('Gagal memuat status VIP: $error');
          },
        );
  }

  void _setVip(String? uid) {
    if (!mounted || _vipUid == uid) return;
    setState(() {
      _vipUid = uid;
      if (uid == null) {
        _character = SpendingCardCharacter.jajanku;
        _cardColor = null;
      }
      _image = _renderImage();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _planSubscription?.cancel();
    super.dispose();
  }

  Future<Uint8List> _renderImage() async {
    final hideAmounts = _hideAmounts;
    final messageVariant = _messageVariant;
    final character = _isVip ? _character : SpendingCardCharacter.jajanku;
    final cardColor = _isVip ? _cardColor : null;
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
      character: character,
      cardColor: cardColor,
    );
  }

  Future<void> _export(Uint8List bytes, {required bool share}) async {
    if (!_isVip &&
        (_character != SpendingCardCharacter.jajanku || _cardColor != null)) {
      _setVip(null);
      return;
    }
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
        final ready =
            snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done;
        final bytes = ready ? snapshot.data : null;
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: _isVip
                        ? (constraints.maxHeight * 0.55).clamp(260.0, 600.0)
                        : (constraints.maxHeight - 140).clamp(260.0, 900.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ready
                          ? Image.memory(bytes!, fit: BoxFit.contain)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  if (_isVip)
                    SpendingCardCustomizer(
                      character: _character,
                      cardColor: _cardColor,
                      enabled: !_busy,
                      onCharacterChanged: (value) {
                        if (!_isVip || _busy) return;
                        setState(() {
                          _character = value;
                          _image = _renderImage();
                        });
                      },
                      onColorChanged: (value) {
                        if (!_isVip || _busy) return;
                        setState(() {
                          _cardColor = value;
                          _image = _renderImage();
                        });
                      },
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
                            onPressed: _busy || !ready
                                ? null
                                : () => _export(bytes!, share: false),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Unduh'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy || !ready
                                ? null
                                : () => _export(bytes!, share: true),
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
            ),
          ),
        );
      },
    ),
  );
}
