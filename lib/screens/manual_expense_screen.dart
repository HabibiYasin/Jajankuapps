import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../services/transaction_classifier.dart';

class ManualExpenseScreen extends StatefulWidget {
  final bool isIncome;
  const ManualExpenseScreen({super.key, this.isIncome = false});

  @override
  State<ManualExpenseScreen> createState() => _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends State<ManualExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _source = TextEditingController(text: 'Tunai');
  String _paymentMethod = 'Cash';
  String _category = 'Umum';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.isIncome) _category = 'Gaji';
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    setState(
      () => _date = DateTime(
        date.year,
        date.month,
        date.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amount.text);
    Navigator.pop(
      context,
      TransactionModel(
        type: widget.isIncome ? 'income' : 'expense',
        merchant: _merchant.text.trim(),
        nominalStr: 'Rp${amount.toStringAsFixed(0)}',
        numericNominal: amount,
        category: _category,
        dateTime: _date,
        source: _source.text.trim(),
        paymentMethod: _paymentMethod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isIncome ? 'Catat Pemasukan' : 'Catat Manual'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _merchant,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.isIncome
                    ? 'Asal pemasukan'
                    : 'Nama pengeluaran / merchant',
                hintText: widget.isIncome
                    ? 'Contoh: Gaji dari perusahaan'
                    : 'Contoh: Makan siang',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? (widget.isIncome
                        ? 'Isi asal pemasukan.'
                        : 'Isi nama pengeluaran.')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                hintText: '25000',
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || !amount.isFinite || amount <= 0
                    ? 'Isi nominal lebih dari 0.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items:
                  (widget.isIncome
                          ? TransactionModel.incomeCategories
                          : TransactionClassifier.categories)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
              items: TransactionModel.paymentMethods
                  .map(
                    (method) =>
                        DropdownMenuItem(value: method, child: Text(method)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _source,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: widget.isIncome ? 'Uang masuk ke' : 'Sumber Uang',
                hintText: 'Contoh: BCA, DANA, Tunai',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Isi sumber uang.'
                  : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                widget.isIncome ? 'Tanggal pemasukan' : 'Tanggal pengeluaran',
              ),
              subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                widget.isIncome ? 'Simpan Pemasukan' : 'Simpan Pengeluaran',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
