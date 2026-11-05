import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/app_database.dart';
import '../services/data_transfer_service.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key, required this.language});

  final String language;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  static const _serviceId = 'com.awasigogera.milkaccount.data_transfer';
  static const _chunkLength = 12 * 1024;

  final _transferService = DataTransferService();
  final _codeController = TextEditingController();
  final _random = Random.secure();
  final Set<String> _selectedAccounts = {};
  final Map<int, String> _receivedChunks = {};

  List<Map<String, Object?>> _accounts = [];
  String? _sessionCode;
  String? _endpointId;
  String? _transferId;
  String _status = '';
  int _expectedChunks = 0;
  int _mode = 0;
  bool _busy = false;
  bool _advertising = false;
  bool _discovering = false;
  bool _connected = false;
  bool _sent = false;
  bool _handlingBundle = false;

  String _t(String key) {
    const labels = {
      'ur': {
        'title': 'آف لائن ڈیٹا منتقلی',
        'intro': 'دو موبائل کے درمیان کھاتے اور ان کا مکمل ریکارڈ انٹرنیٹ کے بغیر منتقل کریں۔',
        'send': 'ڈیٹا بھیجیں',
        'receive': 'ڈیٹا وصول کریں',
        'select': 'منتقل کرنے کے لیے گاہک منتخب کریں',
        'all': 'تمام منتخب کریں',
        'clear': 'انتخاب ختم کریں',
        'scan': 'وصول کرنے والے موبائل کا QR اسکین کریں',
        'manual': 'یا وصول کرنے والے کا کوڈ درج کریں',
        'connect': 'موبائل تلاش کریں',
        'startReceive': 'وصولی شروع کریں',
        'code': 'کنکشن کوڈ',
        'scanTitle': 'QR کوڈ اسکین کریں',
        'stop': 'کنکشن بند کریں',
        'wait': 'دوسرا موبائل تلاش ہو رہا ہے…',
        'waiting': 'دوسرے موبائل سے کنکشن کا انتظار ہے۔',
        'online': 'کنکشن قائم ہو گیا۔ ڈیٹا منتقل ہو رہا ہے…',
        'sent': 'ڈیٹا بھیج دیا گیا۔ وصولی کی تصدیق کا انتظار ہے۔',
        'received': 'ڈیٹا محفوظ طریقے سے شامل کر دیا گیا۔',
        'empty': 'منتقل کرنے کے لیے پہلے گاہک منتخب کریں۔',
        'badCode': 'QR یا کنکشن کوڈ درست نہیں ہے۔',
        'permission': 'Bluetooth، قریبی ڈیوائسز اور لوکیشن کی اجازت درکار ہے۔',
        'location': 'فون کی Location بھی آن کریں، ورنہ کنکشن نہیں بن سکتا۔',
        'androidOnly': 'براہِ راست آف لائن منتقلی کے لیے دونوں موبائل میں Android ایپ استعمال کریں۔',
        'noAccounts': 'ابھی کوئی کھاتہ موجود نہیں۔',
        'error': 'منتقلی مکمل نہیں ہو سکی',
        'matchTitle': 'ایک جیسے نام کے کئی گاہک ملے',
        'matchBody': 'درست گاہک منتخب کریں جس کے کھاتے میں یہ ریکارڈ شامل کرنا ہے۔',
        'cancel': 'منسوخ',
        'use': 'یہ گاہک منتخب کریں',
        'done': 'مکمل',
        'compare': 'دونوں موبائل پر یہ تصدیقی کوڈ ایک جیسا ہونا چاہیے:',
        'accept': 'کنکشن قبول کریں',
        'reject': 'انکار کریں',
        'selected': 'منتخب',
        'records': 'ریکارڈ',
      },
      'en': {
        'title': 'Offline Data Transfer',
        'intro': 'Transfer customer accounts and their complete history between two phones without internet.',
        'send': 'Send Data',
        'receive': 'Receive Data',
        'select': 'Select customers to transfer',
        'all': 'Select All',
        'clear': 'Clear Selection',
        'scan': 'Scan the receiver phone QR code',
        'manual': 'Or enter the receiver code',
        'connect': 'Find Phone',
        'startReceive': 'Start Receiving',
        'code': 'Connection code',
        'scanTitle': 'Scan QR code',
        'stop': 'Stop Connection',
        'wait': 'Searching for the other phone…',
        'waiting': 'Waiting for the other phone to connect.',
        'online': 'Connected. Transferring data…',
        'sent': 'Data sent. Waiting for receiver confirmation.',
        'received': 'Data was safely merged into this phone.',
        'empty': 'Select at least one customer first.',
        'badCode': 'The QR or connection code is invalid.',
        'permission': 'Bluetooth, nearby-device and location permissions are required.',
        'location': 'Turn on Location on the phone too, or the connection may fail.',
        'androidOnly': 'Use the Android app on both phones for direct offline transfer.',
        'noAccounts': 'There are no customer accounts yet.',
        'error': 'Transfer could not be completed',
        'matchTitle': 'Several customers have matching details',
        'matchBody': 'Choose the local customer whose account should receive these records.',
        'cancel': 'Cancel',
        'use': 'Use this customer',
        'done': 'Done',
        'compare': 'This verification code must match on both phones:',
        'accept': 'Accept Connection',
        'reject': 'Reject',
        'selected': 'selected',
        'records': 'records',
      },
      'hi': {
        'title': 'ऑफ़लाइन डेटा ट्रांसफर',
        'intro': 'बिना इंटरनेट दो मोबाइल के बीच खाते और उनका पूरा रिकॉर्ड भेजें।',
        'send': 'डेटा भेजें',
        'receive': 'डेटा प्राप्त करें',
        'select': 'ट्रांसफर के लिए ग्राहक चुनें',
        'all': 'सभी चुनें',
        'clear': 'चयन हटाएँ',
        'scan': 'प्राप्त करने वाले मोबाइल का QR स्कैन करें',
        'manual': 'या प्राप्त करने वाले का कोड लिखें',
        'connect': 'मोबाइल खोजें',
        'startReceive': 'प्राप्त करना शुरू करें',
        'code': 'कनेक्शन कोड',
        'scanTitle': 'QR कोड स्कैन करें',
        'stop': 'कनेक्शन बंद करें',
        'wait': 'दूसरा मोबाइल खोजा जा रहा है…',
        'waiting': 'दूसरे मोबाइल के कनेक्ट होने का इंतज़ार है।',
        'online': 'कनेक्शन बन गया। डेटा ट्रांसफर हो रहा है…',
        'sent': 'डेटा भेज दिया। प्राप्ति की पुष्टि का इंतज़ार है।',
        'received': 'डेटा सुरक्षित रूप से जोड़ दिया गया।',
        'empty': 'पहले कम से कम एक ग्राहक चुनें।',
        'badCode': 'QR या कनेक्शन कोड सही नहीं है।',
        'permission': 'Bluetooth, Nearby Devices और Location की अनुमति चाहिए।',
        'location': 'फोन की Location भी चालू करें।',
        'androidOnly': 'सीधे ऑफ़लाइन ट्रांसफर के लिए दोनों फोन में Android ऐप चाहिए।',
        'noAccounts': 'अभी कोई खाता मौजूद नहीं है।',
        'error': 'ट्रांसफर पूरा नहीं हो सका',
        'matchTitle': 'एक जैसे नाम वाले कई ग्राहक मिले',
        'matchBody': 'वह ग्राहक चुनें जिसके खाते में रिकॉर्ड जोड़ना है।',
        'cancel': 'रद्द करें',
        'use': 'यह ग्राहक चुनें',
        'done': 'पूरा',
        'compare': 'दोनों फोन पर यह पुष्टि कोड एक जैसा होना चाहिए:',
        'accept': 'कनेक्शन स्वीकार करें',
        'reject': 'अस्वीकार करें',
        'selected': 'चुने गए',
        'records': 'रिकॉर्ड',
      },
    };
    return labels[widget.language]?[key] ?? labels['en']![key]!;
  }

  bool get _androidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('accounts', orderBy: 'account_number ASC');
      if (mounted) setState(() => _accounts = rows);
    } catch (error) {
      _showMessage('${_t('error')}: $error');
    }
  }

  Future<void> _preparePermissions() async {
    if (!_androidSupported) throw StateError(_t('androidOnly'));
    final requested = await <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    final required = [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ];
    if (required.any((permission) => requested[permission]?.isGranted != true)) {
      throw StateError(_t('permission'));
    }
    if (requested[Permission.locationWhenInUse]?.isGranted != true) {
      throw StateError(_t('permission'));
    }
    if (!await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      throw StateError(_t('location'));
    }
  }

  Future<void> _startReceiving() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '';
      _sessionCode = (100000 + _random.nextInt(900000)).toString();
      _connected = false;
      _endpointId = null;
      _receivedChunks.clear();
      _expectedChunks = 0;
      _transferId = null;
      _handlingBundle = false;
    });
    try {
      await _preparePermissions();
      final started = await Nearby().startAdvertising(
        'MA-$_sessionCode',
        Strategy.P2P_STAR,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      if (!started) throw StateError('Nearby advertising did not start.');
      if (mounted) {
        setState(() {
          _advertising = true;
          _status = _t('waiting');
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      _showMessage('${_t('error')}: $error');
      await _stopNearby();
    }
  }

  Future<void> _beginDiscovery(String rawCode) async {
    final code = _normalizeCode(rawCode);
    if (code == null) {
      _showMessage(_t('badCode'));
      return;
    }
    if (_selectedAccounts.isEmpty) {
      _showMessage(_t('empty'));
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = _t('wait');
      _connected = false;
      _sent = false;
      _endpointId = null;
    });
    try {
      await _preparePermissions();
      await Nearby().startDiscovery(
        'MilkAccount-Sender',
        Strategy.P2P_STAR,
        onEndpointFound: (id, name, serviceId) {
          if (!mounted || _endpointId != null || name != 'MA-$code') return;
          setState(() {
            _endpointId = id;
            _status = _t('wait');
          });
          unawaited(Nearby().stopDiscovery());
          unawaited(Nearby().requestConnection(
            'MilkAccount-Sender',
            id,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          ).then<void>((_) {}, onError: (Object error, StackTrace stack) {
            if (mounted) _showMessage('${_t('error')}: $error');
          }));
        },
        onEndpointLost: (id) {
          if (mounted && _endpointId == id && !_connected) {
            setState(() {
              _endpointId = null;
              _status = _t('wait');
            });
          }
        },
        serviceId: _serviceId,
      );
      if (mounted) {
        setState(() {
          _discovering = true;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      _showMessage('${_t('error')}: $error');
      await _stopNearby();
    }
  }

  String? _normalizeCode(String value) {
    var code = value.trim().toUpperCase();
    if (code.startsWith('MILKACCOUNT1:')) {
      code = code.substring('MILKACCOUNT1:'.length);
    }
    if (code.startsWith('MA-')) code = code.substring(3);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return null;
    return code;
  }

  Future<void> _onConnectionInitiated(String id, ConnectionInfo info) async {
    if (!mounted) {
      await Nearby().rejectConnection(id);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('accept')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.endpointName),
            const SizedBox(height: 12),
            Text(_t('compare')),
            const SizedBox(height: 8),
            SelectableText(
              info.authenticationToken,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, letterSpacing: 4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('reject')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('accept')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      await Nearby().rejectConnection(id);
      return;
    }
    _endpointId = id;
    await Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (endpointId, update) {
        if (!mounted) return;
        if (update.status == PayloadStatus.FAILURE) {
          setState(() => _status = '${_t('error')}: payload transfer failed');
        }
      },
    );
    setState(() {
      _connected = true;
      _status = _t('online');
    });
  }

  void _onConnectionResult(String id, Status status) {
    if (!mounted) return;
    final value = status.toString().toUpperCase();
    if (value.contains('CONNECTED')) {
      setState(() {
        _connected = true;
        _status = _t('online');
      });
      if (_mode == 0 && !_sent) unawaited(_sendSelectedBundle(id));
    } else if (value.contains('REJECT') || value.contains('ERROR')) {
      setState(() {
        _connected = false;
        _status = '${_t('error')}: $status';
      });
    }
  }

  void _onDisconnected(String id) {
    if (!mounted) return;
    setState(() {
      _connected = false;
      _endpointId = null;
      _status = 'Connection closed.';
    });
  }

  Future<void> _sendSelectedBundle(String endpointId) async {
    if (_sent) return;
    _sent = true;
    try {
      final bundle = await _transferService.createBundle(_selectedAccounts.toList());
      final encoded = base64Encode(utf8.encode(bundle));
      final transferId = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999999)}';
      final total = (encoded.length / _chunkLength).ceil();
      for (var index = 0; index < total; index++) {
        final start = index * _chunkLength;
        final end = min(start + _chunkLength, encoded.length);
        final packet = jsonEncode({
          'type': 'milk_account_chunk',
          'transfer_id': transferId,
          'index': index,
          'total': total,
          'data': encoded.substring(start, end),
        });
        await Nearby().sendBytesPayload(
          endpointId,
          Uint8List.fromList(utf8.encode(packet)),
        );
        if (!mounted) return;
        setState(() => _status = '${_t('online')} ${index + 1}/$total');
      }
      if (mounted) setState(() => _status = _t('sent'));
    } catch (error) {
      if (mounted) setState(() => _status = '${_t('error')}: $error');
    }
  }

  Future<void> _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    try {
      final packet = jsonDecode(utf8.decode(payload.bytes!));
      if (packet is! Map) throw const FormatException('Invalid transfer packet.');
      if (packet['type'] == 'milk_account_ack') {
        if (mounted) setState(() => _status = 'The other phone confirmed the transfer.');
        return;
      }
      if (packet['type'] != 'milk_account_chunk') {
        throw const FormatException('Unknown transfer packet.');
      }
      final transferId = packet['transfer_id'];
      final index = packet['index'];
      final total = packet['total'];
      final data = packet['data'];
      if (transferId is! String ||
          index is! int ||
          total is! int ||
          data is! String ||
          total < 1 ||
          total > 50000 ||
          index < 0 ||
          index >= total) {
        throw const FormatException('Transfer packet values are invalid.');
      }
      if (_transferId != transferId) {
        _transferId = transferId;
        _receivedChunks.clear();
        _expectedChunks = total;
      }
      if (_expectedChunks != total) {
        throw const FormatException('Transfer packet count changed unexpectedly.');
      }
      _receivedChunks[index] = data;
      if (mounted) {
        setState(() => _status = '${_t('online')} ${_receivedChunks.length}/$_expectedChunks');
      }
      if (_receivedChunks.length != _expectedChunks || _handlingBundle) return;
      _handlingBundle = true;
      final encoded = List.generate(_expectedChunks, (i) => _receivedChunks[i] ?? '').join();
      if (encoded.isEmpty || List.generate(_expectedChunks, (i) => _receivedChunks.containsKey(i)).any((has) => !has)) {
        throw const FormatException('Some transfer packets are missing.');
      }
      final bundle = utf8.decode(base64Decode(encoded));
      final result = await _mergeWithCustomerChoices(bundle);
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'milk_account_ack',
          'inserted_accounts': result.insertedAccounts,
        }))),
      );
      if (mounted) {
        setState(() {
          _status = '${_t('received')} (+${result.insertedAccounts} accounts)';
          _handlingBundle = false;
        });
      }
    } catch (error) {
      _handlingBundle = false;
      if (mounted) setState(() => _status = '${_t('error')}: $error');
    }
  }

  Future<TransferMergeResult> _mergeWithCustomerChoices(String bundle) async {
    final resolutions = <String, String>{};
    while (true) {
      try {
        final result = await _transferService.mergeBundle(
          bundle,
          resolutions: resolutions,
        );
        return result;
      } on AmbiguousAccountMatchException catch (error) {
        final selected = await _chooseMatchingCustomer(error);
        if (selected == null) rethrow;
        resolutions[error.sourceAccount['id'] as String] = selected;
      }
    }
  }

  Future<String?> _chooseMatchingCustomer(
    AmbiguousAccountMatchException error,
  ) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('matchTitle')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t('matchBody')),
              const SizedBox(height: 10),
              ...error.candidates.map((candidate) => ListTile(
                    title: Text(candidate['customer_name']?.toString() ?? ''),
                    subtitle: Text(candidate['phone_number']?.toString() ?? ''),
                    onTap: () => Navigator.pop(dialogContext, candidate['id'] as String),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQr() async {
    final scanned = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('scanTitle')),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final raw = capture.barcodes.first.rawValue;
                if (raw != null) Navigator.pop(dialogContext, raw);
              },
            ),
          ),
        ),
      ),
    );
    if (scanned != null && mounted) {
      _codeController.text = _normalizeCode(scanned) ?? scanned;
      await _beginDiscovery(_codeController.text);
    }
  }

  Future<void> _stopNearby() async {
    if (!_androidSupported) return;
    try {
      await Nearby().stopAllEndpoints();
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
    } catch (_) {
      // Stopping an already stopped endpoint is harmless.
    }
    if (mounted) {
      setState(() {
        _advertising = false;
        _discovering = false;
        _connected = false;
        _endpointId = null;
        _sessionCode = null;
        _status = '';
      });
    }
  }

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    if (_androidSupported) unawaited(_stopNearby());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_t('title'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 64, color: Color(0xFF0756C9)),
              const SizedBox(height: 10),
              Text(_t('intro'), textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(_t('send')), icon: const Icon(Icons.upload_rounded)),
                  ButtonSegment(value: 1, label: Text(_t('receive')), icon: const Icon(Icons.download_rounded)),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) async {
                  await _stopNearby();
                  if (mounted) setState(() {
                    _mode = selection.first;
                    _status = '';
                  });
                },
              ),
              const SizedBox(height: 18),
              if (!_androidSupported)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_t('androidOnly'), textAlign: TextAlign.center),
                  ),
                )
              else if (_mode == 0)
                _buildSendPanel()
              else
                _buildReceivePanel(),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFE9F4FF),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_status, textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (_busy) const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              if (_advertising || _discovering || _connected) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _stopNearby,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_t('stop')),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildSendPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_t('select'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        if (_accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(_t('noAccounts'), textAlign: TextAlign.center),
          )
        else ...[
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _selectedAccounts.addAll(_accounts.map((a) => a['id'] as String))),
                child: Text(_t('all')),
              ),
              TextButton(
                onPressed: () => setState(_selectedAccounts.clear),
                child: Text(_t('clear')),
              ),
              const Spacer(),
              Text('${_selectedAccounts.length} ${_t('selected')}'),
            ],
          ),
          Card(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final id = account['id'] as String;
                  return CheckboxListTile(
                    value: _selectedAccounts.contains(id),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selectedAccounts.add(id);
                      } else {
                        _selectedAccounts.remove(id);
                      }
                    }),
                    title: Text('${account['customer_name']}'),
                    subtitle: Text('${_t('code')}: ${account['account_number']}'),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(_t('scan'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scanQr,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(_t('scanTitle')),
        ),
        const SizedBox(height: 8),
        Text(_t('manual')),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.password_rounded),
            hintText: '123456',
          ),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _beginDiscovery(_codeController.text),
          icon: const Icon(Icons.bluetooth_searching_rounded),
          label: Text(_t('connect')),
        ),
      ],
    );
  }

  Widget _buildReceivePanel() {
    if (_sessionCode == null || !_advertising) {
      return Column(
        children: [
          const Icon(Icons.phone_android_rounded, size: 58, color: Color(0xFF0875E1)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _startReceiving,
            icon: const Icon(Icons.wifi_tethering_rounded),
            label: Text(_t('startReceive')),
          ),
        ],
      );
    }
    return Column(
      children: [
        Text(_t('waiting'), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFB7D9F7)),
          ),
          child: QrImageView(
            data: 'MILKACCOUNT1:MA-$_sessionCode',
            size: 230,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(_t('code')),
        SelectableText(
          _sessionCode!,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 6),
        ),
      ],
    );
  }
}
