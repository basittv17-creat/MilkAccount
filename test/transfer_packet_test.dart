import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:milk_account/services/transfer_packet_codec.dart';

void main() {
  group('two-peer offline packet simulation', () {
    test('receiver reconstructs a large bundle when packets arrive out of order', () {
      final bundle = jsonEncode({
        'format': 'milk_account_transfer',
        'version': 1,
        'accounts': List.generate(
          35,
          (index) => {
            'id': 'customer-$index',
            'customer_name': 'Customer $index',
            'history': List.filled(80, 'milk-entry-$index'),
          },
        ),
      });
      final senderPackets = TransferPacketCodec.encodeBundle(
        bundle,
        transferId: 'sender-device-session-1',
        chunkLength: 96,
      );
      expect(senderPackets.length, greaterThan(2));

      // The sender and receiver are isolated peers; this in-memory queue
      // represents the byte payload channel provided by Nearby Connections.
      final virtualPeerChannel = senderPackets.reversed.toList();
      final receiver = TransferPacketAssembler();
      String? receivedBundle;
      for (final packet in virtualPeerChannel) {
        receivedBundle = receiver.add(packet) ?? receivedBundle;
      }

      expect(receivedBundle, bundle);
      expect(jsonDecode(receivedBundle!)['accounts'], hasLength(35));
      expect(receiver.receivedCount, senderPackets.length);
    });

    test('receiver waits until every chunk arrives', () {
      final packets = TransferPacketCodec.encodeBundle(
        'complete-transfer-payload',
        transferId: 'session-2',
        chunkLength: 5,
      );
      final receiver = TransferPacketAssembler();
      expect(receiver.add(packets.first), isNull);
      expect(receiver.receivedCount, 1);
      for (final packet in packets.skip(1)) {
        receiver.add(packet);
      }
      expect(receiver.receivedCount, packets.length);
    });

    test('rejects malformed packets and inconsistent packet totals', () {
      final receiver = TransferPacketAssembler();
      expect(
        () => receiver.add(Uint8List.fromList(utf8.encode('{broken}'))),
        throwsFormatException,
      );
      final packet = TransferPacketCodec.encodeBundle(
        'payload-that-needs-several-packets',
        transferId: 'session-3',
        chunkLength: 4,
      ).first;
      receiver.add(packet);
      final changedTotal = utf8.encode(jsonEncode({
        'type': 'milk_account_chunk',
        'transfer_id': 'session-3',
        'index': 1,
        'total': 99,
        'data': 'YWJjZA==',
      }));
      expect(() => receiver.add(Uint8List.fromList(changedTotal)), throwsFormatException);
    });
  });
}
