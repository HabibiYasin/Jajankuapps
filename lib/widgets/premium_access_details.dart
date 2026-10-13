import 'package:flutter/material.dart';

import '../models/premium_status.dart';

class PremiumAccessDetails extends StatelessWidget {
  const PremiumAccessDetails({super.key, required this.status});

  final PremiumStatus status;

  String _date(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} (waktu perangkat)';
  }

  @override
  Widget build(BuildContext context) {
    if (status.isLifetime) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Premium seumur hidup'),
          Text('Akses premium tanpa batas waktu. Tidak perlu membeli paket.'),
          SizedBox(height: 8),
          Text(
            'Jika sebelumnya berlangganan di Google Play, batalkan langganan tersebut agar tagihan tidak berlanjut.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status.startedAt != null)
          Text('Mulai premium: ${_date(status.startedAt!)}'),
        if (status.endedAt != null)
          Text('Periode premium berakhir: ${_date(status.endedAt!)}'),
        Text(
          status.autoRenewing
              ? 'Perpanjangan otomatis aktif.'
              : 'Tidak diperpanjang otomatis.',
        ),
      ],
    );
  }
}
