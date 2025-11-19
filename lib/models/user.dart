import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 9)
class User extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String email;

  @HiveField(3)
  String? emailVerifiedAt;

  @HiveField(4)
  String password;

  @HiveField(5)
  String? role;

  @HiveField(6)
  int? productorId;

  @HiveField(7)
  String? rememberToken;

  @HiveField(8)
  String? createdAt;

  @HiveField(9)
  String? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerifiedAt,
    required this.password,
    this.role,
    this.productorId,
    this.rememberToken,
    this.createdAt,
    this.updatedAt,
  });
}
