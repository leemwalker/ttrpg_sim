import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNotNull;
import 'package:ttrpg_sim/core/database/database.dart';

void main() {
  late AppDatabase database;
  late GameDao dao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = GameDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Quest DAO Tests', () {
    test('Create and Fetch Quest', () async {
      await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        tone: const Value('Standard'),
        description: 'Desc',
      ));

      final questId = await dao.createQuest(
        worldId: 1, // Auto-increment starts at 1
        title: 'Kill Rats',
        description: 'Slay 5 rats',
        status: 'active',
      );

      final quest = await dao.getQuest(questId);

      expect(quest != null, true);
      expect(quest!.title, 'Kill Rats');
      expect(quest.status, 'active');
      expect(quest.description, 'Slay 5 rats');
    });

    test('Update Quest Status', () async {
      await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        tone: const Value('Standard'),
        description: 'Desc',
      ));
      final questId = await dao.createQuest(
        worldId: 1,
        title: 'Kill Rats',
        description: 'Slay 5 rats',
        status: 'active',
      );

      await dao.updateQuestStatus(questId, 'completed');
      final quest = await dao.getQuest(questId);

      expect(quest!.status, 'completed');
    });

    test('Get Quests by Status', () async {
      await dao.createWorld(WorldsCompanion.insert(
        name: 'Test World',
        genre: 'Fantasy',
        tone: const Value('Standard'),
        description: 'Desc',
      ));
      await dao.createQuest(
          worldId: 1, title: 'Active Quest', description: '', status: 'active');
      await dao.createQuest(
          worldId: 1,
          title: 'Completed Quest',
          description: '',
          status: 'completed');

      final activeQuests = await dao.getQuestsByStatus(1, 'active');
      expect(activeQuests.length, 1);
      expect(activeQuests.first.title, 'Active Quest');

      final completedQuests = await dao.getQuestsByStatus(1, 'completed');
      expect(completedQuests.length, 1);
      expect(completedQuests.first.title, 'Completed Quest');
    });
  });
}
