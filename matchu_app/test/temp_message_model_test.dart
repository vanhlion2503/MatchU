import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/temp_messenger_moder.dart';

void main() {
  test('temp message keeps a stable client id for idempotent writes', () {
    final message = TempMessageModel(
      id: 'client-message-1',
      senderId: 'user-a',
      text: 'Xin chào',
    );

    final json = message.toJson();

    expect(message.id, 'client-message-1');
    expect(json['clientMessageId'], 'client-message-1');
    expect(json['status'], 'pending');
    expect(json['clientCreatedAt'], isA<Timestamp>());
    expect(json['createdAt'], isA<FieldValue>());
  });

  test('temp message creates a non-empty id when one is not supplied', () {
    final message = TempMessageModel(senderId: 'user-a', text: 'Hello');

    expect(message.id, isNotEmpty);
  });
}
