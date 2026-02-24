class FieldInfo {
  final String fieldDescription;
  final String fieldPath;
  final String property;
  final String uomLabel;
  final String uomSymbol;

  FieldInfo({
    required this.fieldDescription,
    required this.fieldPath,
    required this.property,
    required this.uomLabel,
    required this.uomSymbol,
  });

  factory FieldInfo.fromJson(Map<String, dynamic> json) {
    return FieldInfo(
      fieldDescription: json['fieldDescription'],
      fieldPath: json['fieldPath'],
      property: json['property'],
      uomLabel: json['uom_label'],
      uomSymbol: json['uom_symbol'],
    );
  }
}

class MachineInfo {
  final String sourceId;
  final String location;
  final String smartObject;
  final String topic;
  final List<FieldInfo> fields;

  MachineInfo({
    required this.sourceId,
    required this.location,
    required this.smartObject,
    required this.topic,
    required this.fields,
  });

  factory MachineInfo.fromJson(Map<String, dynamic> json) {
    String extractLast(String uri) => uri.split('/').last;

    var fieldList = (json['fields'] as List<dynamic>)
        .map((item) => FieldInfo.fromJson(item))
        .toList();

    return MachineInfo(
      sourceId: json['source_id'],
      location: extractLast(json['site']),
      smartObject: extractLast(json['smart_object']),
      topic: json['topic'],
      fields: fieldList,
    );
  }
}
