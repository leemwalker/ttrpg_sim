import 'package:google_generative_ai/google_generative_ai.dart';

/// Abstract wrapper for GenerativeModel to allow mocking
abstract class GenerativeModelWrapper {
  ChatSessionWrapper startChat({List<Content>? history});
}

/// Abstract wrapper for ChatSession to allow mocking
abstract class ChatSessionWrapper {
  Future<GenerateContentResponse> sendMessage(Content content);
}

/// Real implementation forwarding to Google Generative AI
class GoogleGenerativeModelWrapper implements GenerativeModelWrapper {
  final GenerativeModel _model;

  GoogleGenerativeModelWrapper(this._model);

  @override
  ChatSessionWrapper startChat({List<Content>? history}) {
    return GoogleChatSessionWrapper(_model.startChat(history: history));
  }
}

class GoogleChatSessionWrapper implements ChatSessionWrapper {
  final ChatSession _session;

  GoogleChatSessionWrapper(this._session);

  @override
  Future<GenerateContentResponse> sendMessage(Content content) {
    return _session.sendMessage(content);
  }
}
