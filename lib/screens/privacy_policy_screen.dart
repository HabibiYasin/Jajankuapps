import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final Future<String> _policy = rootBundle.loadString(
    'assets/legal/privacy_policy.md',
  );

  List<InlineSpan> _inlineSpans(String text) {
    final spans = <InlineSpan>[];
    final bold = RegExp(r'\*\*(.*?)\*\*');
    var offset = 0;
    for (final match in bold.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kebijakan Privasi')),
    body: FutureBuilder<String>(
      future: _policy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Kebijakan privasi belum bisa dibuka.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: snapshot.data!.split('\n\n').map((paragraph) {
              final heading = paragraph.startsWith('#');
              final text = paragraph
                  .replaceFirst(RegExp(r'^#+\s*'), '')
                  .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
                  .replaceAll(RegExp(r' +\n'), '\n');
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text.rich(
                  TextSpan(children: _inlineSpans(text)),
                  style: heading
                      ? Theme.of(context).textTheme.titleLarge
                      : const TextStyle(fontSize: 16, height: 1.6),
                ),
              );
            }).toList(),
          ),
        );
      },
    ),
  );
}
