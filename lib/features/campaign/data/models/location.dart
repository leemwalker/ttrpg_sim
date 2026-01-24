import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

@freezed
class Location with _$Location {
  const factory Location({
    required String id,
    required String name,
    required String description,
    @Default(false) bool isKnown,
    @Default([]) List<String> npcIds,
    @Default([]) List<String> connectedLocationIds,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}
