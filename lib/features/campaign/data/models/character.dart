import 'package:freezed_annotation/freezed_annotation.dart';

part 'character.freezed.dart';
part 'character.g.dart';

@freezed
class Character with _$Character {
  const factory Character({
    required String id,
    required String name,
    required String race,
    required String charClass,
    required int level,
    required Map<String, int> stats, // STR, DEX, CON, INT, WIS, CHA
    @Default(0) int hp,
    @Default(0) int maxHp,
    @Default(0) int ac,
    @Default([]) List<String> inventoryIds,
    @Default('') String background,
    @Default('') String alignment,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
}
