// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationModelAdapter extends TypeAdapter<ConversationModel> {
  @override
  final int typeId = 1;

  @override
  ConversationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationModel(
      topic: fields[0] as String,
      peerAddress: fields[1] as String,
      lastMessage: fields[2] as String?,
      lastMessageAt: fields[3] as DateTime?,
      createdAt: fields[4] as DateTime,
      unreadCount: fields[5] as int,
      consentState: fields[6] as String? ?? 'allowed',
    );
  }

  @override
  void write(BinaryWriter writer, ConversationModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.topic)
      ..writeByte(1)
      ..write(obj.peerAddress)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.lastMessageAt)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.unreadCount)
      ..writeByte(6)
      ..write(obj.consentState);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
