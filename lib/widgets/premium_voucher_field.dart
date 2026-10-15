import 'package:flutter/material.dart';

class PremiumVoucherField extends StatefulWidget {
  const PremiumVoucherField({
    super.key,
    this.appliedCode,
    this.message,
    required this.busy,
    required this.onApply,
    required this.onRemove,
  });
  final String? appliedCode;
  final String? message;
  final bool busy;
  final ValueChanged<String> onApply;
  final VoidCallback onRemove;
  @override
  State<PremiumVoucherField> createState() => _PremiumVoucherFieldState();
}

class _PremiumVoucherFieldState extends State<PremiumVoucherField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.appliedCode ?? '',
  );
  @override
  void didUpdateWidget(covariant PremiumVoucherField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appliedCode != oldWidget.appliedCode &&
        widget.appliedCode != null) {
      _controller.text = widget.appliedCode!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _controller.text.trim().toLowerCase();
    if (code.isNotEmpty && !widget.busy) widget.onApply(code);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            enabled: !widget.busy,
            maxLength: 80,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Kode voucher',
              hintText: 'Masukkan kode voucher',
              helperText:
                  'cobapremium otomatis dipilih jika akun memenuhi syarat.',
            ),
            onSubmitted: (_) => _apply(),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: widget.busy ? null : _apply,
                child: const Text('Terapkan'),
              ),
              TextButton(
                onPressed: widget.busy
                    ? null
                    : () {
                        _controller.clear();
                        widget.onRemove();
                      },
                child: const Text('Hapus voucher'),
              ),
            ],
          ),
          if (widget.message != null) Text(widget.message!),
        ],
      ),
    ),
  );
}
