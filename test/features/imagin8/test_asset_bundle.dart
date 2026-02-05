import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/imagin8/core_decks.csv') {
      return 'Deck,Type,Name,Description,Mechanic\nFantasy,Trait,Brave,Face danger,"{""trait"":true}"\nFantasy,Ability,Sword,Slash,"{""damage"":1}"';
    }
    return '';
  }

  @override
  Future<ByteData> load(String key) async {
    final str = await loadString(key);
    return ByteData.view(Uint8List.fromList(utf8.encode(str)).buffer);
  }
}
