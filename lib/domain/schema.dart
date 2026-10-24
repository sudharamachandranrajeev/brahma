import 'json.dart';

/// Builders for the JSON schemas the AI answers in. Structured outputs need
/// every property required and no extra properties, so unknown values come
/// back as '' or [] rather than missing.
Json object(Map<String, Json> properties, {String? description}) => {
  'type': 'object',
  'description': ?description,
  'properties': properties,
  'required': properties.keys.toList(),
  'additionalProperties': false,
};

Json array(Json items, {String? description}) => {
  'type': 'array',
  'description': ?description,
  'items': items,
};

Json string([String? description]) => {'type': 'string', 'description': ?description};

Json integer([String? description]) => {'type': 'integer', 'description': ?description};

Json number([String? description]) => {'type': 'number', 'description': ?description};

Json boolean([String? description]) => {'type': 'boolean', 'description': ?description};

Json oneOf(List<String> values, [String? description]) => {
  'type': 'string',
  'enum': values,
  'description': ?description,
};

Json strings([String? description]) => array(string(), description: description);

/// Web pages a researched answer relied on.
final sourcesSchema = array(
  object({'title': string(), 'url': string()}),
  description: 'Web pages you relied on, most important first.',
);

/// Checks [value] against [schema] (the subset the builders above make).
/// Returns the first problem as a path and reason, or null when it conforms.
/// Streamed tool input is not validated by the API, so the client does it.
String? violation(Json schema, Object? value, [String path = r'$']) {
  switch (schema['type']) {
    case 'object':
      if (value is! Map) return '$path is not an object';
      final props = obj(schema['properties']);
      for (final key in strs(schema['required'])) {
        if (!value.containsKey(key)) return '$path.$key is missing';
      }
      for (final e in props.entries) {
        if (!value.containsKey(e.key)) continue;
        final v = violation(obj(e.value), value[e.key], '$path.${e.key}');
        if (v != null) return v;
      }
    case 'array':
      if (value is! List) return '$path is not a list';
      final items = obj(schema['items']);
      for (final (i, e) in value.indexed) {
        final v = violation(items, e, '$path[$i]');
        if (v != null) return v;
      }
    case 'string':
      if (value is! String) return '$path is not text';
      final allowed = schema['enum'];
      if (allowed is List && !allowed.contains(value)) return '$path is not one of ${allowed.join(', ')}';
    case 'integer':
      if (value is! num || value != value.roundToDouble()) return '$path is not a whole number';
    case 'number':
      if (value is! num) return '$path is not a number';
    case 'boolean':
      if (value is! bool) return '$path is not true or false';
  }
  return null;
}
