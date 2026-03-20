import 'package:hive/hive.dart';
import '../../services/api/api_service.dart';

part 'conversation_model.g.dart';

@HiveType(typeId: 1)
class ConversationModel extends HiveObject {
  @HiveField(0)
  String topic;

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

  factory ConversationModel.fromBackend(BackendConversation backendConversation) {
    return ConversationModel(
      topic: backendConversation.topic,
      peerAddress: backendConversation.peerAddress,
      lastMessage: backendConversation.lastMessage?.content,
      lastMessageAt: backendConversation.lastMessage?.sentAt,
      createdAt: backendConversation.createdAt,
    );
  }

  void updateLastMessage(String message, DateTime sentAt) {
    lastMessage = message;
    lastMessageAt = sentAt;
    save();
  }
}
