import 'dart:convert';
import 'dart:typed_data';

/// Encodes a transfer bundle into the byte packets sent over Nearby Connections.
class TransferPacketCodec {
  const TransferPacketCodec._();

  static List<Uint8List> encodeBundle(
    String bundle, {
    required String transferId,
    int chunkLength = 12 * 1024,
  }) {
    if (bundle.isEmpty || transferId.isEmpty || chunkLength < 1) {
      throw ArgumentError('Bundle, transfer ID and a positive chunk length are required.');
    }
    final encoded = base64Encode(utf8.encode(bundle));
    final total = (encoded.length / chunkLength).ceil();
    return List<Uint8List>.generate(total, (index) {
      final start = index * chunkLength;
      final end = start + chunkLength < encoded.length
          ? start + chunkLength
          : encoded.length;
      final packet = jsonEncode({
        'type': 'milk_account_chunk',
        'transfer_id': transferId,
        'index': index,
        'total': total,
        'data': encoded.substring(start, end),
      });
      return Uint8List.fromList(utf8.encode(packet));
    });
  }
}

/// Reassembles packets received from a peer, including out-of-order delivery.
class TransferPacketAssembler {
  String? _transferId;
  int? _totalChunks;
  final Map<int, String> _chunks = {};
  String? _completedBundle;

  int get receivedCount => _chunks.length;
  int get totalChunks => _totalChunks ?? 0;

  void reset() {
    _transferId = null;
    _totalChunks = null;
    _chunks.clear();
    _completedBundle = null;
  }

  /// Returns the decoded bundle once every chunk has arrived; otherwise null.
  String? add(Uint8List bytes) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map || decoded['type'] != 'milk_account_chunk') {
      throw const FormatException('Unknown transfer packet.');
    }
    final transferId = decoded['transfer_id'];
    final index = decoded['index'];
    final total = decoded['total'];
    final data = decoded['data'];
    if (transferId is! String ||
        transferId.isEmpty ||
        index is! int ||
        total is! int ||
        data is! String ||
        total < 1 ||
        total > 50000 ||
        index < 0 ||
        index >= total ||
        data.isEmpty) {
      throw const FormatException('Transfer packet values are invalid.');
    }

    if (_transferId != transferId) {
      reset();
      _transferId = transferId;
      _totalChunks = total;
    }
    if (_totalChunks != total) {
      throw const FormatException('Transfer packet count changed unexpectedly.');
    }
    final previous = _chunks[index];
    if (previous != null && previous != data) {
      throw const FormatException('A transfer packet index was reused with different data.');
    }
    _chunks[index] = data;
    if (_chunks.length != total) return null;
    if (_completedBundle != null) return _completedBundle;

    final encoded = List.generate(total, (i) {
      final chunk = _chunks[i];
      if (chunk == null) throw const FormatException('Some transfer packets are missing.');
      return chunk;
    }).join();
    try {
      _completedBundle = utf8.decode(base64Decode(encoded));
    } on FormatException {
      throw const FormatException('The received transfer data is damaged.');
    }
    return _completedBundle;
  }
}
