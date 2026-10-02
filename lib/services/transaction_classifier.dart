import '../data/transaction_keywords.dart';

class CategoryPrediction {
  final String category;
  final List<String> matchedKeywords;
  const CategoryPrediction(this.category, this.matchedKeywords);
  bool get needsReview => category == 'Umum';
}

class TransactionClassifier {
  static const categories = [
    'Makanan',
    'Minuman',
    'Jajan',
    'Belanja',
    'Tagihan & Pulsa',
    'Lifestyle',
    'Transportasi',
    'Umum',
  ];

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[’\x27]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static final _rules =
      [
            ...transactionKeywords,
            // A grocery product, not a ready-to-drink beverage.
            ('susu formula', 'Belanja', 3),
          ]
          .map(
            (entry) => (
              words: normalize(entry.$1).split(' '),
              keyword: entry.$1,
              category: entry.$2,
              strength: entry.$3,
            ),
          )
          .toList();

  // These words also occur in personal names or unrelated products.
  static const _ambiguousWords = {
    'tri',
    'vivo',
    'solar',
    'shell',
    'haus',
    'ades',
    'cleo',
    'tang',
    'subway',
    'sederhana',
    'pagi sore',
    'steam',
  };
  static const _retailers = {
    'alfamart',
    'alfamidi',
    'indomaret',
    'super indo',
    'hypermart',
    'transmart',
    'lotte mart',
    'ranch market',
    'farmers market',
    'aeon supermarket',
    'hari hari',
    'yogya',
    'borma',
    'tip top',
    'tokopedia',
    'shopee',
    'lazada',
    'blibli',
    'bukalapak',
    'tiktok shop',
    'zalora',
    'sociolla',
  };

  static CategoryPrediction classify({
    required String merchant,
    String receiptText = '',
  }) {
    final merchantResult = _match(merchant);
    final details = _details(receiptText);
    final detailResult = _match(details);
    // An explicit item/description can refine a generic retailer/platform.
    if (merchantResult.$2 <= 1 && detailResult.$2 > 1) return detailResult.$1;
    if (merchantResult.$2 > 0) return merchantResult.$1;
    return detailResult.$1;
  }

  static (CategoryPrediction, int) _match(String text) {
    final normalized = normalize(text);
    final tokens = normalized.split(' ');
    final matches =
        <
          ({int start, int end, String category, String keyword, int strength})
        >[];
    for (final rule in _rules) {
      if (_ambiguousWords.contains(rule.keyword) &&
          normalized != normalize(rule.keyword)) {
        continue;
      }
      if (rule.strength == 1 && !_retailers.contains(rule.keyword)) continue;
      for (var start = 0; start <= tokens.length - rule.words.length; start++) {
        var equal = true;
        for (var offset = 0; offset < rule.words.length; offset++) {
          if (tokens[start + offset] != rule.words[offset]) {
            equal = false;
            break;
          }
        }
        if (equal) {
          matches.add((
            start: start,
            end: start + rule.words.length,
            category: rule.category,
            keyword: rule.keyword,
            strength: rule.strength,
          ));
        }
      }
    }
    // A contained word must not compete with its more specific phrase:
    // "roti" inside "roti bakar", "kopi" inside "permen kopi", etc.
    final specific = matches
        .where(
          (match) => !matches.any(
            (other) =>
                other.start <= match.start &&
                other.end >= match.end &&
                other.end - other.start > match.end - match.start,
          ),
        )
        .toList();
    if (specific.isEmpty) return (const CategoryPrediction('Umum', []), 0);
    final maxStrength = specific
        .map((m) => m.strength)
        .reduce((a, b) => a > b ? a : b);
    final candidates = specific
        .where((m) => m.strength == maxStrength)
        .toList();
    final categories = candidates.map((m) => m.category).toSet();
    final keywords = candidates.map((m) => m.keyword).toSet().toList()..sort();
    if (categories.length != 1) {
      return (CategoryPrediction('Umum', keywords), maxStrength);
    }
    return (CategoryPrediction(categories.single, keywords), maxStrength);
  }

  static String _details(String receipt) {
    // Only explicit purchase descriptions; never classify from bank names,
    // payment methods, sender names, addresses, adverts, or generic "top up".
    final lines = receipt.split(RegExp(r'[\r\n]+'));
    final details = <String>[];
    final label = RegExp(
      r'^(?:keterangan|catatan|deskripsi|produk|nama produk|item|nama item|layanan)(?:\s*[:\-]\s*|\s+)(.+)$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = label.firstMatch(line.trim());
      if (match != null) details.add(match.group(1)!);
    }
    return details.join(' ; ');
  }
}
