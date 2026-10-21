import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class AutomaticTutorialScreen extends StatefulWidget {
  const AutomaticTutorialScreen({super.key});

  @override
  State<AutomaticTutorialScreen> createState() =>
      _AutomaticTutorialScreenState();
}

class _AutomaticTutorialScreenState extends State<AutomaticTutorialScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: 'YE9e0dBhQg0',
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          interfaceLanguage: 'id',
          captionLanguage: 'id',
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _openYoutube() async {
    try {
      await _controller?.pauseVideo();
      final opened = await launchUrl(
        Uri.parse('https://www.youtube.com/shorts/YE9e0dBhQg0'),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Keep the tutorial available when no external app can handle the link.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tidak bisa membuka YouTube. Coba lagi nanti.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Cara tambah otomatis')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tonton cara mencatat pengeluaran otomatis dari bukti pembayaran.',
            ),
            const SizedBox(height: 16),
            if (controller != null) ...[
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).height * 0.34,
                  ),
                  child: YoutubePlayer(
                    controller: controller,
                    aspectRatio: 9 / 16,
                  ),
                ),
              ),
              YoutubeValueBuilder(
                controller: controller,
                builder: (context, value) => value.hasError
                    ? const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Video belum bisa diputar di sini. Coba buka di YouTube.',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ] else
              const Text('Tonton panduan melalui tombol Buka di YouTube.'),
            const SizedBox(height: 16),
            const Text('Video membutuhkan koneksi internet.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openYoutube,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka di YouTube'),
            ),
          ],
        ),
      ),
    );
  }
}
