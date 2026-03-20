import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel extends HiveObject {
  @HiveField(0)
  String id; // XMTP message ID

  @HiveField(1)
  String conversationTopic;

  @HiveField(2)
  String sender;

  @HiveField(3)
  String content;

  @HiveField(4)
  DateTime sentAt;

  @HiveField(5)
  bool isSynced; // true if from XMTP, false if pending send

  @HiveField(6)
  String? status; // pending, sent, failed

  MessageModel({
    required this.id,
    required this.conversationTopic,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.isSynced = true,
    this.status = 'sent',
  });

  // Create from XMTP DecodedMessage
  factory MessageModel.fromXmtp(dynamic xmtpMessage, String topic) {
    return MessageModel(
      id: xmtpMessage.id,
      conversationTopic: topic,
      sender: xmtpMessage.sender.hex,
      content: xmtpMessage.content.toString(),
      sentAt: xmtpMessage.sentAt,
      isSynced: true,
      status: 'sent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationTopic': conversationTopic,
      'sender': sender,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      'isSynced': isSynced,
      'status': status,
    };
  }
}
