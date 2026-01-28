import 'package:mockito/annotations.dart';
import 'package:ttrpg_sim/core/database/database.dart';
import 'package:ttrpg_sim/core/services/gemini_service.dart';
import 'package:ttrpg_sim/core/rules/rpg_system.dart';

@GenerateMocks([GameDao, GeminiService, RpgSystem])
void main() {}
