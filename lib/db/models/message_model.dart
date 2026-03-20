import 'package:hive/hive.dart';
import '../../services/api/api_service.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String conversationTopic;

  @HiveField(2)
  String sender;

  @HiveField(3)
  String content;

  @HiveField(4)
  DateTime sentAt;

  @HiveField(5)
  bool isSynced;

  @HiveField(6)
  String? status;

  MessageModel({
    required this.id,
    required this.conversationTopic,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.isSynced = true,
    this.status = 'sent',
  });

  factory MessageModel.fromBackend(BackendMessage backendMessage, String topic) {
    return MessageModel(
      id: backendMessage.id,
      conversationTopic: topic,
      sender: backendMessage.sender,
      content: backendMessage.content,
      sentAt: backendMessage.sentAt,
      isSynced: (backendMessage.status ?? 'sent') == 'sent',
      status: backendMessage.status ?? 'sent',
    );
  }
}
