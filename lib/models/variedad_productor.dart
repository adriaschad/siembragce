import 'package:hive/hive.dart';

part 'variedad_productor.g.dart';

@HiveType(typeId: 5)
class VariedadProductor extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int productorId;

  @HiveField(2)
  int variedadId;

  VariedadProductor({
    required this.id,
    required this.productorId,
    required this.variedadId,
  });
}
