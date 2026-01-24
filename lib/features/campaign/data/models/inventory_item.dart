import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_item.freezed.dart';
part 'inventory_item.g.dart';

@freezed
class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required String id,
    required String name,
    required String description,
    required int quantity,
    @Default(false) bool isMagical,
    @Default({}) Map<String, dynamic> attributes,
  }) = _InventoryItem;

  factory InventoryItem.fromJson(Map<String, dynamic> json) =>
      _$InventoryItemFromJson(json);
}
