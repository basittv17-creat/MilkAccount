import 'package:flutter/material.dart';

import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.language});

  final String language;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _service = BackupService();
  bool _busy = false;

  String _text(String key) {
    const labels = {
      'ur': {
        'title': 'بیک اپ اور ڈیٹا منتقلی',
        'description': 'اپنے تمام کھاتوں، دودھ کی انٹریوں، ادائیگیوں اور ناگا کا ڈیٹا محفوظ کریں یا واپس بحال کریں۔',
        'export': 'بیک اپ محفوظ کریں',
        'import': 'بیک اپ سے ڈیٹا بحال کریں',
        'warning': 'بحالی کے دوران موجودہ ڈیٹا کی حفاظتی کاپی بھی بنائی جائے گی۔',
        'saved': 'بیک اپ کامیابی سے محفوظ ہو گیا۔',
        'restored': 'ڈیٹا کامیابی سے بحال ہو گیا۔',
        'cancelled': 'عمل منسوخ کر دیا گیا۔',
        'error': 'عمل مکمل نہیں ہو سکا',
        'confirmTitle': 'ڈیٹا بحال کریں؟',
        'confirmBody': 'اس بیک اپ سے موجودہ ڈیٹا تبدیل ہو جائے گا۔ کیا آپ جاری رکھنا چاہتے ہیں؟',
        'cancel': 'واپس',
        'confirm': 'بحال کریں',
      },
      'en': {
        'title': 'Backup & Data Transfer',
        'description': 'Save or restore all accounts, milk entries, payments and no-milk days.',
        'export': 'Save Backup',
        'import': 'Restore from Backup',
        'warning': 'A safety copy of the current database is kept before restoring.',
        'saved': 'Backup saved successfully.',
        'restored': 'Data restored successfully.',
        'cancelled': 'Operation cancelled.',
        'error': 'Operation could not be completed',
        'confirmTitle': 'Restore data?',
        'confirmBody': 'The selected backup will replace the current data. Do you want to continue?',
        'cancel': 'Cancel',
        'confirm': 'Restore',
      },
      'hi': {
        'title': 'बैकअप और डेटा ट्रांसफर',
        'description': 'सभी खाते, दूध की एंट्री, भुगतान और नागा का डेटा सुरक्षित करें या वापस लाएँ।',
        'export': 'बैकअप सेव करें',
        'import': 'बैकअप से डेटा वापस लाएँ',
        'warning': 'डेटा वापस लाने से पहले मौजूदा डेटाबेस की सुरक्षा कॉपी रखी जाएगी।',
        'saved': 'बैकअप सफलतापूर्वक सेव हो गया।',
        'restored': 'डेटा सफलतापूर्वक वापस आ गया।',
        'cancelled': 'प्रक्रिया रद्द कर दी गई।',
        'error': 'प्रक्रिया पूरी नहीं हो सकी',
        'confirmTitle': 'डेटा वापस लाएँ?',
        'confirmBody': 'चुना गया बैकअप मौजूदा डेटा की जगह लेगा। क्या आप जारी रखना चाहते हैं?',
        'cancel': 'रद्द करें',
        'confirm': 'वापस लाएँ',
      },
    };
    return labels[widget.language]?[key] ?? labels['en']![key]!;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message('${_text('error')}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final path = await _service.exportBackup();
    if (!mounted) return;
    _message(path == null ? _text('cancelled') : _text('saved'));
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('confirmTitle')),
        content: Text(_text('confirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final restored = await _service.restoreBackup();
      if (mounted) {
        _message(restored ? _text('restored') : _text('cancelled'));
      }
    });
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: Scaffold(
        appBar: AppBar(title: Text(_text('title'))),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(
              Icons.backup_rounded,
              size: 76,
              color: Color(0xFF0756C9),
            ),
            const SizedBox(height: 18),
            Text(
              _text('description'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(_export),
              icon: const Icon(Icons.save_alt_rounded),
              label: Text(_text('export')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: Text(_text('import')),
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 20),
            Text(
              _text('warning'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
      ));
}
