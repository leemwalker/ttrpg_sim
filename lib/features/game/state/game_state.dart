import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';

part 'game_state.freezed.dart';

@freezed
class GameState with _$GameState {
  const factory GameState({
    @Default([]) List<ChatMessage> messages,
    CharacterData? character,
    @Default([]) List<InventoryData> inventory,
    @Default(false) bool isLoading,
  }) = _GameState;
}
