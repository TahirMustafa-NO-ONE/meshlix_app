import 'package:hive/hive.dart';

part 'conversation_model.g.dart';

@HiveType(typeId: 1)
class ConversationModel extends HiveObject {
  @HiveField(0)
  String topic; // XMTP conversation topic (unique ID)

  @HiveField(1)
  String peerAddress;

  @HiveField(2)
  String? lastMessage;

  @HiveField(3)
  DateTime? lastMessageAt;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  int unreadCount;

  ConversationModel({
    required this.topic,
    required this.peerAddress,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.unreadCount = 0,
  });

  // Create from XMTP Conversation
  factory ConversationModel.fromXmtp(dynamic xmtpConversation) {
    return ConversationModel(
      topic: xmtpConversation.topic,
      peerAddress: xmtpConversation.peer.hex,
      createdAt: DateTime.now(),
    );
  }

  void updateLastMessage(String message, DateTime sentAt) {
    lastMessage = message;
    lastMessageAt = sentAt;
    save(); // Auto-save to Hive
  }

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'peerAddress': peerAddress,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
