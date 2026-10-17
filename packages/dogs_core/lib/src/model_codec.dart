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
  /// Converts non-null input values to strings before construction.
  final bool stringify;

  /// Declares a serializable model with optional read rules.
  ///
  /// Field selection for [DogModelCodec.toJson] is per-call via
  /// [EncodeOptions.include].
  const JsonModel({this.stringify = false}) : super(serializable: true);

  @override
  void beforeDeserialization(Map<String, dynamic> map, DogStructure structure, DogEngine engine) {
    final source = Map<String, dynamic>.from(map);
    for (final field in structure.fields) {
      final key = field.firstAnnotationOf<JsonKey>();
      final fromJsonKeys = key?.fromJsonKeys;
      if (fromJsonKeys != null) map[field.name] = key!.readFromJsonKeysValue(source);
    }
    if (stringify) map.updateAll((key, value) => value?.toString());
  }

  @override
  void postSerialization(
      dynamic obj, Map<String, dynamic> map, DogStructure structure, DogEngine engine) {}
}

/// Structure field handle used by [EncodeOptions].
///
/// Prefer generated [DogFieldRef]s such as `MyModel$.fieldName`. Equality is by
/// [name] (structure field name, for example `name_ku` for Dart `nameKu`).
class DogField {
  /// Structure field name used by [DogModelCodec.toJson].
  final String name;

  /// Creates a field handle from a structure field [name].
  const DogField(this.name);

  @override
  bool operator ==(Object other) => other is DogField && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => "DogField($name)";
}

/// Typed compile-time field handle for model [T].
///
/// Generated as `MyModel$.fieldName`. Use these in [EncodeOptions.include],
/// [EncodeOptions.rename], and [EncodeOptions.also].
class DogFieldRef<T> extends DogField {
  /// Creates a typed reference to a structure field on [T].
  const DogFieldRef(super.name);

  @override
  String toString() => "DogFieldRef<$T>($name)";
}

/// Per-call encode rules for [DogModelCodec.toJson].
///
/// [include], [rename], and [also] use [DogField] / [DogFieldRef] handles.
/// [rename] / [also] apply while walking nested models; [include] applies only
/// at the current level (use [forType] for nested allow lists).
class EncodeOptions {
  /// Whitelist of structure fields to emit. When set, only these fields are written.
  final List<DogField>? include;

  /// Structure field → output JSON key for this call only.
  final Map<DogField, String>? rename;

  /// Structure field → extra output keys that always receive the same value.
  final Map<DogField, List<String>>? also;

  /// Merged into the result after fields are written (overwrites colliding keys).
  final Map<String, dynamic>? extras;

  /// Nested-type overrides; [rename] / [also] still inherit from the parent.
  final Map<Type, EncodeOptions>? forType;

  /// Creates encode rules for one [DogModelCodec.toJson] call.
  const EncodeOptions({
    this.include,
    this.rename,
    this.also,
    this.extras,
    this.forType,
  });

  /// Structure field name for a [DogField] / [DogFieldRef].
  static String fieldName(DogField key) => key.name;

  /// Options used when encoding a nested registered model of [type].
  EncodeOptions forChild(Type type) {
    final specific = forType?[type];
    if (specific == null) {
      return EncodeOptions(rename: rename, also: also, forType: forType);
    }
    return EncodeOptions(
      include: specific.include,
      rename: {
        if (rename != null) ...rename!,
        if (specific.rename != null) ...specific.rename!,
      },
      also: {
        if (also != null) ...also!,
        if (specific.also != null) ...specific.also!,
      },
      extras: specific.extras,
      forType: forType,
    );
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
/// 3. resolve [fromJsonKey] / [fromJsonKeys] / field name
/// 4. [onNullValue] when the resolved value is `null` (missing or explicit null)
/// 5. [convert] for the whole field, or [each] for list elements
///
/// Encode notes:
/// - [fromJsonKeys] are decode-only and never auto-emitted
/// - default output key is [fromJsonKey] ?? structure field name
/// - dual-write extra keys with [EncodeOptions.also] on [DogModelCodec.toJson]
class JsonKey<T> extends StructureMetadata with FieldSerializationHook {
  /// Alternative input names; decode-only (do not auto-encode).
  final List<String>? fromJsonKeys;

  /// Preferred decode JSON key; also the default encode key when set.
  final String? fromJsonKey;

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

  /// Declares field-level JSON rules for decode keys, conversion, and fixed values.
  const JsonKey({
    this.fromJsonKeys,
    this.fromJsonKey,
    this.convert,
    this.each,
    this.onNullValue,
    this.forceValue = jsonKeyUnset,
  });

  /// Whether [forceValue] was supplied, including an explicit null.
  bool hasFixedValue() => !identical(forceValue, jsonKeyUnset);

  /// Returns the first [fromJsonKeys] entry with a non-null value, or null.
  String? resolveFromJsonKeys(JsonMap json) {
    final keys = fromJsonKeys;
    if (keys == null) return null;
    for (final key in keys) {
      if (json[key] != null) return key;
    }
    return null;
  }

  /// Reads from the original map so [fromJsonKeys] never affect each other.
  Object? readFromJsonKeysValue(JsonMap json) => json[resolveFromJsonKeys(json)];

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
      if (keyMeta?.fromJsonKey != null) {
        final named = keyMeta!.fromJsonKey!;
        final namedValue = json[named];
        if (namedValue != null || keyMeta.fromJsonKeys == null) {
          key = named;
          raw = namedValue;
        } else {
          key = keyMeta.resolveFromJsonKeys(json) ?? named;
          raw = keyMeta.readFromJsonKeysValue(json);
        }
      } else if (keyMeta?.fromJsonKeys != null) {
        key = keyMeta!.resolveFromJsonKeys(json) ?? field.name;
        raw = keyMeta.readFromJsonKeysValue(json);
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
      if (isList && (nested != null || keyMeta?.each != null || value is List)) {
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
          return null;
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

  /// Encodes [model] to a JSON-ready map.
  ///
  /// Nested registered models and lists of registered models are encoded
  /// recursively. [encodeAs] is a string-keyed shorthand for [EncodeOptions.rename].
  /// [extras] merges after field writes (same as [EncodeOptions.extras]).
  Map<String, dynamic> toJson<T>(
    T model, {
    EncodeOptions? options,
    Map<String, String>? encodeAs,
    Map<String, dynamic>? extras,
  }) {
    final merged = _mergeEncodeOptions(options, encodeAs, extras);
    return writeStructure(structure(T), model, options: merged);
  }

  /// Encodes one generated structure with optional [EncodeOptions].
  Map<String, dynamic> writeStructure(
    DogStructure descriptor,
    dynamic model, {
    EncodeOptions? options,
  }) {
    final values = descriptor.proxy.getFieldValues(model);
    final known = {for (final field in descriptor.fields) field.name};
    final include = _resolveFieldSet(options?.include, known, "include");
    final rename = _resolveRenameMap(options?.rename, known);
    final also = _resolveAlsoMap(options?.also, known);
    final result = <String, dynamic>{};

    for (var index = 0; index < descriptor.fields.length; index++) {
      final field = descriptor.fields[index];
      if (include != null && !include.contains(field.name)) {
        continue;
      }

      final keyMeta = field.firstAnnotationOf<JsonKey>();
      final defaultKey = keyMeta?.fromJsonKey ?? field.name;
      final outKey = rename[field.name] ?? defaultKey;
      final encoded = encodeValue(values[index], field, options);

      result[outKey] = encoded;

      final alsoKeys = also[field.name];
      if (alsoKeys != null) {
        for (final extraKey in alsoKeys) {
          if (extraKey == outKey) continue;
          result[extraKey] = encoded;
        }
      }
    }

    final mergeExtras = options?.extras;
    if (mergeExtras != null) result.addAll(mergeExtras);
    return result;
  }

  /// Recursively encodes a field value for [writeStructure].
  dynamic encodeValue(dynamic value, DogStructureField field, EncodeOptions? options) {
    if (value == null) return null;

    final serialType = field.serial.typeArgument;
    final nested = engine.findStructureByType(serialType);
    final isList = field.iterableKind == IterableKind.list;

    if (isList) {
      final items = value as Iterable;
      if (nested != null) {
        final childOptions = options?.forChild(serialType);
        return [
          for (final item in items) writeStructure(nested, item, options: childOptions),
        ];
      }
      return [for (final item in items) item];
    }

    if (nested != null) {
      return writeStructure(nested, value, options: options?.forChild(serialType));
    }
    return value;
  }

  EncodeOptions? _mergeEncodeOptions(
    EncodeOptions? options,
    Map<String, String>? encodeAs,
    Map<String, dynamic>? extras,
  ) {
    if (options == null && encodeAs == null && extras == null) return null;
    return EncodeOptions(
      include: options?.include,
      rename: {
        if (options?.rename != null) ...options!.rename!,
        if (encodeAs != null)
          for (final entry in encodeAs.entries) DogField(entry.key): entry.value,
      },
      also: options?.also,
      extras: {
        if (options?.extras != null) ...options!.extras!,
        if (extras != null) ...extras,
      },
      forType: options?.forType,
    );
  }

  Set<String>? _resolveFieldSet(List<DogField>? keys, Set<String> known, String label) {
    if (keys == null) return null;
    final resolved = <String>{};
    for (final key in keys) {
      final name = key.name;
      if (!known.contains(name)) {
        throw ArgumentError.value(key, label, "Unknown field '$name'. Known: $known");
      }
      resolved.add(name);
    }
    return resolved;
  }

  /// Keeps only keys present on [known]. Other keys are ignored here so parent
  /// calls can pass nested-field renames that apply while walking children.
  Map<String, String> _resolveRenameMap(Map<DogField, String>? rename, Set<String> known) {
    if (rename == null || rename.isEmpty) return const {};
    final resolved = <String, String>{};
    for (final entry in rename.entries) {
      final name = entry.key.name;
      if (!known.contains(name)) continue;
      resolved[name] = entry.value;
    }
    return resolved;
  }

  /// Keeps only keys present on [known]; nested-only keys pass through [forChild].
  Map<String, List<String>> _resolveAlsoMap(
      Map<DogField, List<String>>? also, Set<String> known) {
    if (also == null || also.isEmpty) return const {};
    final resolved = <String, List<String>>{};
    for (final entry in also.entries) {
      final name = entry.key.name;
      if (!known.contains(name)) continue;
      resolved[name] = List<String>.from(entry.value);
    }
    return resolved;
  }

}
