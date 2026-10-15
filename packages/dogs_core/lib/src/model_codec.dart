import "package:dogs_core/dogs_core.dart";

/// Sentinel for an unset [JsonKey.forceValue], so explicit `null` stays expressible.
class JsonKeyUnset {
  /// Creates the shared unset sentinel.
  const JsonKeyUnset();
}

/// Marker used when [JsonKey.forceValue] is omitted.
const jsonKeyUnset = JsonKeyUnset();

/// Parent JSON map passed to [JsonKey] callbacks.
typedef JsonMap = Map<String, dynamic>;

/// Whole-field or list-element converter; [value] is the raw JSON input.
typedef JsonConvert<T> = T? Function(JsonMap json, Object? value);

/// Null-default supplier invoked when the resolved input is null.
typedef JsonOnNull<T> = T? Function(JsonMap json);

/// Declares JSON model rules without changing native DOGs coercion defaults.
class JsonModel extends Structure implements SerializationHook {
  /// Fields allowed in [DogModelCodec.toJson], or all fields when null.
  final List<String>? outputKeys;

  /// Converts non-null input values to strings before construction.
  final bool stringify;

  /// Returns a fresh empty list for missing or null list fields on this model.
  final bool emptyListsOnNull;

  /// Declares a serializable model with optional read and write rules.
  const JsonModel({this.outputKeys, this.stringify = false, this.emptyListsOnNull = false})
      : super(serializable: true);

  @override
  void beforeDeserialization(Map<String, dynamic> map, DogStructure structure, DogEngine engine) {
    final source = Map<String, dynamic>.from(map);
    for (final field in structure.fields) {
      final key = field.firstAnnotationOf<JsonKey>();
      final aliases = key?.aliases;
      if (aliases != null) map[field.name] = key!.readAliasValue(source);
    }
    if (stringify) map.updateAll((key, value) => value?.toString());
  }

  @override
  void postSerialization(
      dynamic obj, Map<String, dynamic> map, DogStructure structure, DogEngine engine) {
    final keys = outputKeys;
    if (keys != null) map.removeWhere((key, value) => !keys.contains(key));
  }
}

/// Unified field JSON rules for [DogModelCodec].
///
/// [T] is the Dart field type. Callbacks return [T?] for type-safe wiring while
/// still accepting raw JSON [Object?] input. Prefer `@JsonKey<MyType>(...)`
/// when tear-offs should be checked against [T].
///
/// Decode order:
/// 1. explicit [DogModelCodec.fromJson] `values` overrides
/// 2. [forceValue] when set (including explicit `null`)
/// 3. resolve [name] / [aliases] / field name
/// 4. [onNullValue] when the resolved value is `null` (missing or explicit null)
/// 5. [convert] for the whole field, or [each] for list elements
class JsonKey<T> extends StructureMetadata with FieldSerializationHook {
  /// Alternative input names; the generated field name remains the output name.
  final List<String>? aliases;

  /// Explicit input key; defaults to the generated field name when omitted.
  final String? name;

  /// Converts the whole field using the parent map and raw resolved value.
  final JsonConvert<T>? convert;

  /// Converts each list element using the parent map and that element.
  final JsonConvert<T>? each;

  /// Supplies a [T?] when the resolved input is null (missing or explicit null).
  final JsonOnNull<T>? onNullValue;

  /// Forces this decode value when not [jsonKeyUnset], including explicit null.
  ///
  /// Kept as [Object?] so [jsonKeyUnset] can represent "not set" separately from
  /// a forced `null`. At runtime the value should be a [T?].
  final Object? forceValue;

  /// Declares field-level JSON rules for aliases, conversion, and fixed values.
  const JsonKey({
    this.aliases,
    this.name,
    this.convert,
    this.each,
    this.onNullValue,
    this.forceValue = jsonKeyUnset,
  });

  /// Whether [forceValue] was supplied, including an explicit null.
  bool hasFixedValue() => !identical(forceValue, jsonKeyUnset);

  /// Returns the first alias key with a non-null value, or null if none match.
  String? readAliasKey(JsonMap json) {
    final keys = aliases;
    if (keys == null) return null;
    for (final key in keys) {
      if (json[key] != null) return key;
    }
    return null;
  }

  /// Reads from the original map so aliases never affect each other.
  Object? readAliasValue(JsonMap json) => json[readAliasKey(json)];

  @override
  void beforeFieldDeserialization(NativeStructureContext context,
      NativeStructureFieldContext fieldContext, Map<String, dynamic> map, DogEngine engine) {
    if (hasFixedValue()) map[fieldContext.key] = forceValue;
  }
}

/// Common explicit conversions that are not inferred from Dart field types.
///
/// Use the static methods as constant tear-offs with [JsonKey], for example
/// `@JsonKey<String>(convert: JsonConversions.stringify)`.
class JsonConversions {
  /// Converts a non-null value to its string representation.
  static String? stringify(JsonMap json, Object? value) => value?.toString();

  /// Converts booleans to 0/1, retains integers, and defaults other values to 0.
  static int flagInt(JsonMap json, Object? value) => value is bool
      ? (value ? 1 : 0)
      : value is int
          ? value
          : 0;

  /// Truncates a numeric value toward zero; rejects non-numeric values.
  static int integer(JsonMap json, Object? value) => (value as num).toInt();

  /// Constant `false` for [JsonKey.onNullValue].
  static bool falseValue(JsonMap json) => false;

  /// Constant `true` for [JsonKey.onNullValue].
  static bool trueValue(JsonMap json) => true;

  /// Constant `0` for [JsonKey.onNullValue].
  static int zero(JsonMap json) => 0;
}

/// Controls nested-object/list diagnostics without adding a codec dependency.
class DogModelGuard {
  /// Uses strict JSON container types and reports malformed fields as formats.
  const DogModelGuard();

  /// Parses an optional object, retaining its field name in errors.
  T? object<T>(Map<String, dynamic> json, String key, T Function(Map<String, dynamic>) parse) {
    final value = json[key];
    if (value == null) return null;
    try {
      return parse(value as Map<String, dynamic>);
    } catch (error) {
      throw FormatException('Invalid "$key": expected $T. $error', value);
    }
  }

  /// Parses an optional list, retaining its field name and element index.
  List<T>? list<T>(Map<String, dynamic> json, String key, T Function(dynamic) parse) {
    final value = json[key];
    if (value == null) return null;
    if (value is! List) {
      throw FormatException('Invalid "$key": expected List<$T>.', value);
    }
    return [
      for (var index = 0; index < value.length; index++)
        element<T>(value[index], "$key[$index]", parse),
    ];
  }

  /// Parses one list element, reporting its complete indexed field name.
  T element<T>(dynamic value, String key, T Function(dynamic) parse) {
    try {
      return parse(value);
    } catch (error) {
      throw FormatException('Invalid "$key": expected $T. $error', value);
    }
  }
}

/// Maps backend JSON using generated fields while retaining strict Dart casts.
///
/// This opt-in codec does not alter [DogEngine.fromNative]. Scalar values are
/// passed to the generated constructor unchanged unless explicitly converted.
/// JSON hooks outside the annotations documented here use native DOGs modes.
class DogModelCodec {
  /// The engine containing generated model structures.
  final DogEngine engine;

  /// Nested object/list diagnostics, which applications may customize.
  final DogModelGuard guard;

  /// Creates a reusable codec; no global state or engine mutation is required.
  const DogModelCodec({required this.engine, this.guard = const DogModelGuard()});

  /// Finds the generated structure, or reports a missing model registration.
  DogStructure structure(Type type) {
    final result = engine.findStructureByType(type);
    if (result == null) throw StateError("Missing generated model: $type");
    return result;
  }

  /// Reads JSON without mutating input or implicitly coercing scalar numbers.
  ///
  /// Explicit [values] override input annotations, including explicit nulls.
  T fromJson<T>(Map<String, dynamic> json,
          {Map<String, dynamic> values = const {}, bool stringify = false}) =>
      readStructure(structure(T), json, values: values, stringify: stringify) as T;

  /// Reads one generated structure, recursively decoding registered children.
  dynamic readStructure(DogStructure descriptor, Map<String, dynamic> json,
      {Map<String, dynamic> values = const {}, bool stringify = false}) {
    final strings = stringify || (descriptor.firstAnnotationOf<JsonModel>()?.stringify ?? false);
    final emptyListsOnNull = descriptor.firstAnnotationOf<JsonModel>()?.emptyListsOnNull ?? false;
    final fields = <dynamic>[];
    for (final field in descriptor.fields) {
      if (values.containsKey(field.name)) {
        fields.add(values[field.name]);
        continue;
      }
      final keyMeta = field.firstAnnotationOf<JsonKey>();
      if (keyMeta != null && keyMeta.hasFixedValue()) {
        fields.add(keyMeta.forceValue);
        continue;
      }
      final Object? raw;
      final String key;
      if (keyMeta?.name != null) {
        key = keyMeta!.name!;
        raw = json[key];
      } else if (keyMeta?.aliases != null) {
        key = keyMeta!.readAliasKey(json) ?? field.name;
        raw = keyMeta.readAliasValue(json);
      } else {
        key = field.name;
        raw = json[field.name];
      }
      final Object? value =
          raw == null && keyMeta?.onNullValue != null ? keyMeta!.onNullValue!(json) : raw;
      final input = {key: value};
      if (keyMeta?.convert != null) {
        fields.add(keyMeta!.convert!(json, value));
        continue;
      }
      final isList = field.iterableKind == IterableKind.list;
      final nested = engine.findStructureByType(field.serial.typeArgument);
      if (isList && (nested != null || keyMeta?.each != null || emptyListsOnNull || value is List)) {
        fields.add(field.serial.consumeType(<T>() {
          final result = guard.list<T>(input, key, (item) {
            if (keyMeta?.each != null) return keyMeta!.each!(json, item) as T;
            if (nested != null) {
              return readChild(nested, item as Map<String, dynamic>) as T;
            }
            return item as T;
          });
          if (result != null) return result;
          if (value is Iterable) return List<T>.from(value);
          return emptyListsOnNull ? <T>[] : null;
        }));
        continue;
      }
      if (nested != null) {
        fields.add(field.serial.consumeType(
            <T>() => guard.object<T>(input, key, (data) => readChild(nested, data) as T)));
        continue;
      }
      fields.add(strings ? value?.toString() : value);
    }
    return descriptor.proxy.instantiate(fields);
  }

  /// Decodes a nested registered model with the same structure rules.
  dynamic readChild(DogStructure descriptor, Map<String, dynamic> json) =>
      readStructure(descriptor, json);

  /// Returns raw constructor fields, filtered by [JsonModel.outputKeys].
  ///
  /// Nulls and nested instances are retained; use [DogEngine.toNative] when a
  /// recursively encoded, JSON-ready object graph is required.
  Map<String, dynamic> toJson<T>(T model) {
    final descriptor = structure(T);
    final values = descriptor.proxy.getFieldValues(model);
    final keys = descriptor.firstAnnotationOf<JsonModel>()?.outputKeys;
    return {
      for (var index = 0; index < descriptor.fields.length; index++)
        if (keys == null || keys.contains(descriptor.fields[index].name))
          descriptor.fields[index].name: values[index],
    };
  }
}
