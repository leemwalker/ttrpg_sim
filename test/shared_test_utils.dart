import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ttrpg_sim/core/rules/modular_rules_controller.dart';

class MockRuleDataLoader implements RuleDataLoader {
  final Map<String, String> _data = {};

  void setResponse(String path, String content) => _data[path] = content;

  @override
  Future<String> load(String path) async {
    if (!_data.containsKey(path)) {
      print(
          'DEBUG: Asset not found: "$path". Available keys: ${_data.keys.toList()}');
    }
    return _data[path] ?? '';
  }

  void setupDefaultRules() {
    setResponse('assets/system/MobileRPG - Species.csv',
        'Name,Genre,Stats,Free Traits\r\nHuman,Universal,,None\r\nElf,Fantasy,,None');
    setResponse('assets/system/MobileRPG - Genres.csv',
        'Name,Description,Currency,Themes\r\nFantasy,Desc,GP,Magic\r\nCustom,Desc,GP,None'); // Added Custom
    setResponse('assets/system/MobileRPG - Attributes.csv',
        'Name,Genre,Type,Desc\r\nStrength,Universal,Physical,Power\r\nDexterity,Universal,Physical,Agility\r\nConstitution,Universal,Physical,Health\r\nIntelligence,Universal,Mental,IQ\r\nWisdom,Universal,Mental,Insight\r\nCharisma,Universal,Mental,Presence');
    setResponse('assets/system/MobileRPG - Skills.csv',
        'Name,Genre,Attr,Locked,Desc\r\nAthletics,Universal,STR,FALSE,Run');
    setResponse('assets/system/MobileRPG - Traits.csv',
        'Name,Type,Cost,Genre,Desc,Effect');
    setResponse('assets/system/MobileRPG - Origins.csv',
        'Name,Genre,Skills,Feat,Items,Desc\r\nRefugee,Universal,Athletics,None,,Survivor');
    setResponse('assets/system/MobileRPG - Feats.csv',
        'Name,Genre,Type,Pre,Desc,Effect\r\nNone,Universal,Special,None,No Feat,None');
    setResponse('assets/system/MobileRPG - Items.csv',
        'Name,Genre,Type,Dice,Type,Prop,Cost,Desc\r\nSword,Universal,Weapon,1d8,Slashing,,10,A sharp blade\r\nPotion,Universal,Consumable,,,Heal,10,Restores HP');
  }

  void setTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
}
