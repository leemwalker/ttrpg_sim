import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_sim/features/game/presentation/widgets/action_card.dart';

void main() {
  group('ActionCard Widget Tests', () {
    testWidgets('displays title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard(
              title: 'Fireball',
              subtitle: 'Deal fire damage',
              icon: Icons.local_fire_department,
            ),
          ),
        ),
      );

      expect(find.text('Fireball'), findsOneWidget);
      expect(find.text('Deal fire damage'), findsOneWidget);
    });

    testWidgets('displays stats and badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard(
              title: 'Power Attack',
              stats: '2d6 Dmg',
              badge: 'STR',
            ),
          ),
        ),
      );

      expect(find.text('Power Attack'), findsOneWidget);
      expect(find.text('2d6 Dmg'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
    });

    testWidgets('onTap callback fires when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard(
              title: 'Action',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('disabled card does not fire onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard(
              title: 'Disabled Action',
              onTap: () => tapped = true,
              disabled: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionCard));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('skillCheck factory creates correct card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard.skillCheck(
              label: 'Force Open',
              skill: 'Athletics',
              attribute: 'STR',
              difficulty: 15,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Force Open'), findsOneWidget);
      expect(find.text('Athletics'), findsOneWidget);
      expect(find.text('DC 15'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
    });

    testWidgets('spell factory creates correct card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard.spell(
              name: 'Lightning Bolt',
              effect: 'Deals electric damage',
              manaCost: 3,
              damage: '3d6',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('Deals electric damage'), findsOneWidget);
      expect(find.text('3d6'), findsOneWidget);
      expect(find.text('3 MP'), findsOneWidget);
    });

    testWidgets('compact mode hides subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCard(
              title: 'Compact Action',
              subtitle: 'This should be hidden',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Compact Action'), findsOneWidget);
      expect(find.text('This should be hidden'), findsNothing);
    });
  });
}
