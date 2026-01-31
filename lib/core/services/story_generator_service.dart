import 'dart:async';
import 'dart:convert';

import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';

class StoryGeneratorService {
  final GeminiService _geminiService;
  final GameDao _dao;
  final String? _ghostwritingModel;
  final String? _paidApiKey;

  StoryGeneratorService(
    this._geminiService,
    this._dao, {
    String? ghostwritingModel,
    String? paidApiKey,
  })  : _ghostwritingModel = ghostwritingModel,
        _paidApiKey = paidApiKey;

  /// Streams the progress of the book generation.
  /// Yields status messages like "Drafting Chapter 1...".
  /// Returns the full book text upon completion.
  Stream<String> streamBookGeneration(int characterId) async* {
    yield "Fetching story history...";
    final history = await _dao.getFullStoryHistory(characterId);

    if (history.isEmpty) {
      yield "No history found to generate a story.";
      return;
    }

    // chunk history
    final chunks = _chunkMessages(history);
    final totalChapters = chunks.length;

    final StringBuffer bookBuffer = StringBuffer();
    String currentSynopsis = "The story begins...";

    for (int i = 0; i < totalChapters; i++) {
      final chapterNum = i + 1;
      yield "Drafting Chapter $chapterNum of $totalChapters...";

      final chunk = chunks[i];
      final chapterText = await _generateChapter(chunk, currentSynopsis);

      bookBuffer.writeln("CHAPTER $chapterNum");
      bookBuffer.writeln("");
      bookBuffer.writeln(chapterText.content);
      bookBuffer.writeln("");
      bookBuffer.writeln("---"); // Chapter break
      bookBuffer.writeln("");

      currentSynopsis = chapterText.synopsis;
    }

    yield "Finalizing manuscript...";
    // In a real app we might do one final pass for formatting or Table of Contents

    yield "COMPLETE:${bookBuffer.toString()}";
  }

  /// Analyzes the current narrative arc for pacing and loose threads.
  Future<String> analyzeArc(int characterId) async {
    final history = await _dao.getRecentMessages(characterId, 50);
    // Reverse to get chronological order for the analysis
    final recentHistory = history.reversed.toList();

    final prompt = _buildAnalysisPrompt(recentHistory);

    try {
      return await _geminiService.generateContent(
        prompt,
        modelOverride: _ghostwritingModel,
        apiKeyOverride: _paidApiKey,
      );
    } catch (e) {
      return "Unable to analyze arc at this time: $e";
    }
  }

  List<List<ChatMessage>> _chunkMessages(List<ChatMessage> messages) {
    List<List<ChatMessage>> chunks = [];
    List<ChatMessage> currentChunk = [];
    // int currentTokenCount = 0; // Removed unused variable

    // Rough token estimation: 4 chars per token?
    // Or just count messages. Let's do 25 messages per chapter for now to keep it simple.
    const int messagesPerChapter = 25;

    for (var msg in messages) {
      currentChunk.add(msg);
      if (currentChunk.length >= messagesPerChapter) {
        chunks.add(List.from(currentChunk));
        currentChunk.clear();
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  Future<({String content, String synopsis})> _generateChapter(
      List<ChatMessage> chunk, String previousSynopsis) async {
    final conversationText = chunk
        .map((m) => "${m.role.name.toUpperCase()}: ${m.content}")
        .join("\n\n");

    final prompt = """
You are a professional LitRPG fantasy author. 
Your task is to convert the following raw gameplay chat log into a compelling novel chapter.
The story should be written in third-person limited (focusing on the player character).

CRITICAL INSTRUCTIONS:
1. **NARRATIVE FLOW**: Rewrite the dialogue and actions into a cohesive prose narrative. Show, don't just tell.
2. **SYSTEM MESSAGES**: Any game system messages (combat logs, stat updates, level ups) MUST be preserved but formatted distinctly.
   Wrap all system notifications in a special Markdown block like this:
   > **SYSTEM**
   > [Level Up! You are now Level 2]
   > [Skill Gained: Power Strike]
3. **BLUE BOXES**: The user refers to these system messages as "Blue Boxes". Ensure they stand out.
4. **CONTEXT**: The story so far: $previousSynopsis

RAW CHAT LOG:
$conversationText

OUTPUT FORMAT:
Return a JSON object with this exact structure:
{
  "chapter_text": "The full narrative text of the chapter...",
  "synopsis": "A summarized update of the story including events in this chapter, for the next context window."
}
""";

    // We need a way to call Gemini.
    // As mentioned, accessing the internal model of GeminiService is tricky.
    // I will assume I can add `generateAuxiliaryContent` to GeminiService.
    // For now, I will write the code assuming that method exists, and then I will update GeminiService.

    try {
      final response = await _geminiService.generateContent(
        prompt,
        modelOverride: _ghostwritingModel,
        apiKeyOverride: _paidApiKey,
      );
      final json = jsonDecode(
          response.replaceAll("```json", "").replaceAll("```", "").trim());
      return (
        content: json['chapter_text'] as String,
        synopsis: json['synopsis'] as String
      );
    } catch (e) {
      return (
        content: "Error generating chapter: $e",
        synopsis: previousSynopsis
      );
    }
  }

  String _buildAnalysisPrompt(List<ChatMessage> messages) {
    final log = messages.map((m) => "${m.role.name}: ${m.content}").join("\n");
    return "Analyze the narrative arc of the following recent gameplay logs. Identify loose threads, pacing issues, and readiness for a climax.\n\nLOGS:\n$log";
  }
}
