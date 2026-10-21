import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/splash_screen.dart';
import '../services/app_update_service.dart';

/// Lives above the Navigator so existing routes and dialogs cannot cover the gate.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.checkForUpdate,
    required this.child,
    this.openStore,
    this.packageName = 'com.jajanku.app',
  });
  final String packageName;
  final Future<AppUpdatePolicy?> Function() checkForUpdate;
  final Future<bool> Function()? openStore;
  final Widget child;
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _hasOpenedApp = false;
  bool _openingStore = false;
  String? _error;
  AppUpdatePolicy? _policy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final policy = await widget.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _policy = policy;
        if (policy == null) _hasOpenedApp = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_policy == null) _hasOpenedApp = true;
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _update() async {
    setState(() {
      _openingStore = true;
      _error = null;
    });
    try {
      final opened =
          await (widget.openStore?.call() ??
              launchUrl(
                Uri.https('play.google.com', '/store/apps/details', {
                  'id': widget.packageName,
                }),
                mode: LaunchMode.externalApplication,
              ));
      if (!opened) throw StateError('Store unavailable');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak bisa membuka Play Store. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _policy != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasOpenedApp)
          Offstage(
            offstage: blocked,
            child: TickerMode(
              enabled: !blocked,
              child: ExcludeFocus(excluding: blocked, child: widget.child),
            ),
          ),
        if (!_hasOpenedApp && !blocked) const SplashScreen(),
        if (blocked)
          Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.system_update_rounded,
                          size: 80,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Update diperlukan',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Perbarui Jajanku ke versi terbaru untuk melanjutkan menggunakan aplikasi. Data catatanmu tetap tersimpan.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _openingStore ? null : _update,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Update sekarang'),
                        ),
                        TextButton(
                          onPressed: _checking ? null : _check,
                          child: Text(
                            _checking ? 'Memeriksa…' : 'Periksa lagi',
                          ),
                        ),
                        if (_error != null)
                          Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
