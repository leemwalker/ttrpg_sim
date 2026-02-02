import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart'; // For SkillOption

part 'game_state.freezed.dart';

@freezed
class GameState with _$GameState {
  const factory GameState({
    @Default([]) List<ChatMessage> messages,
    CharacterData? character,
    @Default([]) List<InventoryData> inventory,
    @Default(false) bool isLoading,
    @Default(false) bool isTyping, // Task 4: "Thinking..." indicator
    @Default([])
    List<SkillOption> pendingSkillCheck, // Task 1: Three Card options
    @Default(0) int wordCount,
    @Default(0.0) double bookCompletion, // 0.0 to 1.0 (50k words)
    @Default(false) bool isGeneratingBook,
    @Default('') String generationStatus,
    String? lastError, // Task 4: For SnackBar error display
  }) = _GameState;
}
