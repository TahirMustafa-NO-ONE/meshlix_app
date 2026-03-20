import 'package:hive/hive.dart';

part 'contact_model.g.dart';

@HiveType(typeId: 2)
class ContactModel extends HiveObject {
  @HiveField(0)
  String address; // Wallet address (primary key)

  @HiveField(1)
  String? displayName;

  @HiveField(2)
  DateTime? lastInteractionAt;

  @HiveField(3)
  DateTime createdAt;

  ContactModel({
    required this.address,
    this.displayName,
    this.lastInteractionAt,
    required this.createdAt,
  });

  // Auto-generate display name from address
  String get shortAddress =>
      '${address.substring(0, 6)}...${address.substring(address.length - 4)}';

  String get name => displayName ?? shortAddress;

  void updateInteraction() {
    lastInteractionAt = DateTime.now();
    save(); // Auto-save to Hive
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'displayName': displayName,
      'lastInteractionAt': lastInteractionAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
