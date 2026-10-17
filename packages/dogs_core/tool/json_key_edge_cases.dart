import 'package:dogs_core/dogs_models.dart';

int failures = 0;

void check(String name, bool ok, [Object? detail]) {
  if (ok) {
    print('PASS  $name');
  } else {
    failures++;
    print('FAIL  $name${detail == null ? '' : ' ($detail)'}');
  }
}

void checkThrows(String name, void Function() body, {bool Function(Object error)? match}) {
  try {
    body();
    failures++;
    print('FAIL  $name (expected throw)');
  } catch (error) {
    if (match != null && !match(error)) {
      failures++;
      print('FAIL  $name (wrong error: $error)');
      return;
    }
    print('PASS  $name');
  }
}

class Child {
  Child({this.id, this.label});
  final int? id;
  final String? label;
}

class Sample {
  Sample({
    this.id,
    this.name,
    this.flag,
    this.whole,
    this.numbers,
    this.child,
    this.children,
    this.forced,
    this.points,
    this.ignored = true,
    this.summary,
  });

  final int? id;
  final String? name;
  final int? flag;
  final int? whole;
  final List<int>? numbers;
  final Child? child;
  final List<Child>? children;
  final int? forced;
  final List<List<double>>? points;
  final bool ignored;
  final String? summary;
}

Child parseChild(JsonMap json) => Child(
      id: json['id'] as int?,
      label: json['label']?.toString(),
    );

Child? convertChild(JsonMap json, Object? value) =>
    value == null ? null : parseChild(value as JsonMap);

Child eachChild(JsonMap json, Object? value) => parseChild(value as JsonMap);

int? onNullSeven(JsonMap json) => 7;

int? onNullFromSibling(JsonMap json) => json['fallback'] as int? ?? 9;

String? readSummary(JsonMap json, Object? value) =>
    '${json.containsKey('text') ? json['text'] : 'missing'}:${json['suffix'] ?? ''}';

List<List<double>>? parsePoints(JsonMap json, Object? value) {
  if (value is! List || value.isEmpty) return null;
  return [
    for (final point in value)
      if (point is List && point.length >= 2 && point[0] is num && point[1] is num)
        [(point[0] as num).toDouble(), (point[1] as num).toDouble()],
  ];
}

void registerModel<T>(DogEngine engine, DogStructure<T> structure) {
  engine.registerStructure(structure, emitChangeToStream: false);
  engine.registerAssociatedConverter(DogStructureConverterImpl<T>(structure),
      emitChangeToStream: false);
}

DogStructure<Sample> sampleStructure() => DogStructure<Sample>(
      'Sample',
      StructureConformity.basic,
      [
        DogStructureField.int('id', optional: true, annotations: const [
          JsonKey<int>(aliases: ['legacy_id', 'id'], onNullValue: onNullSeven),
        ]),
        DogStructureField.string('name', optional: true, annotations: const [
          JsonKey<String>(aliases: ['legacy_name', 'name'], convert: JsonConversions.stringify),
        ]),
        DogStructureField.int('flag', optional: true, annotations: const [
          JsonKey<int>(convert: JsonConversions.flagInt, onNullValue: JsonConversions.zero),
        ]),
        DogStructureField.int('whole', optional: true, annotations: const [
          JsonKey<int>(onNullValue: onNullFromSibling, convert: JsonConversions.integer),
        ]),
        DogStructureField.int('numbers',
            optional: true,
            iterable: IterableKind.list,
            annotations: const [JsonKey<int>(each: JsonConversions.integer)]),
        DogStructureField.create<Child>('child', optional: true, annotations: const [
          JsonKey<Child>(key: 'product', convert: convertChild),
        ]),
        DogStructureField.create<Child>(
          'children',
          optional: true,
          iterable: IterableKind.list,
          annotations: const [JsonKey<Child>(key: 'items', each: eachChild)],
        ),
        DogStructureField.int('forced', optional: true, annotations: const [
          JsonKey<int>(forceValue: null, onNullValue: onNullSeven),
        ]),
        DogStructureField.create<Object>('points', optional: true, annotations: const [
          JsonKey(convert: parsePoints),
        ]),
        DogStructureField.bool('ignored', annotations: const [
          JsonKey<bool>(forceValue: false),
        ]),
        DogStructureField.string('summary', optional: true, annotations: const [
          JsonKey<String>(convert: readSummary),
        ]),
      ],
      const [JsonModel()],
      ObjectFactoryStructureProxy<Sample>(
        (values) => Sample(
          id: values[0],
          name: values[1],
          flag: values[2],
          whole: values[3],
          numbers: values[4],
          child: values[5],
          children: values[6],
          forced: values[7],
          points: values[8],
          ignored: values[9],
          summary: values[10],
        ),
        [
          (v) => v.id,
          (v) => v.name,
          (v) => v.flag,
          (v) => v.whole,
          (v) => v.numbers,
          (v) => v.child,
          (v) => v.children,
          (v) => v.forced,
          (v) => v.points,
          (v) => v.ignored,
          (v) => v.summary,
        ],
        (v) => [
          v.id,
          v.name,
          v.flag,
          v.whole,
          v.numbers,
          v.child,
          v.children,
          v.forced,
          v.points,
          v.ignored,
          v.summary,
        ],
      ),
    );

DogModelCodec codec() {
  final engine = DogEngine();
  registerModel(engine, sampleStructure());
  return DogModelCodec(engine: engine);
}

void main() {
  final plain = codec();

  check('alias preferred key', plain.fromJson<Sample>({'legacy_id': 1, 'id': 2}).id == 1);
  check('alias fallback key', plain.fromJson<Sample>({'id': 2}).id == 2);
  check('alias all null uses onNullValue',
      plain.fromJson<Sample>({'legacy_id': null, 'id': null}).id == 7);
  check('alias missing uses onNullValue', plain.fromJson<Sample>({}).id == 7);

  check(
      'name nested convert',
      plain.fromJson<Sample>({
            'product': {'id': 5, 'label': true},
          }).child?.label ==
          'true');
  check('name missing keeps null', plain.fromJson<Sample>({}).child == null);
  checkThrows('bad nested convert throws', () => plain.fromJson<Sample>({'product': 'bad'}));

  check('stringify number', plain.fromJson<Sample>({'legacy_name': 12}).name == '12');
  check('flagInt true', plain.fromJson<Sample>({'flag': true}).flag == 1);
  check('flagInt false', plain.fromJson<Sample>({'flag': false}).flag == 0);
  check('flagInt null -> zero', plain.fromJson<Sample>({}).flag == 0);
  check('integer truncates', plain.fromJson<Sample>({'whole': 2.9}).whole == 2);
  check('onNullValue sibling', plain.fromJson<Sample>({'fallback': 4}).whole == 4);
  check('onNullValue constant', plain.fromJson<Sample>({}).whole == 9);

  check(
      'each converts elements',
      plain.fromJson<Sample>({
            'numbers': [1.9, 2],
          }).numbers!.toString() ==
          '[1, 2]');
  check('each empty list', plain.fromJson<Sample>({'numbers': []}).numbers!.isEmpty);
  check('list missing stays null', plain.fromJson<Sample>({}).numbers == null);
  check('list explicit null stays null', plain.fromJson<Sample>({'numbers': null}).numbers == null);

  final withItems = plain.fromJson<Sample>({
    'items': [
      {'id': 1, 'label': 'a'},
      {'id': 2, 'label': 4},
    ],
  });
  check('list each ids', withItems.children?.map((c) => c.id).toList().toString() == '[1, 2]');
  check('list each labels', withItems.children?.map((c) => c.label).toList().toString() == '[a, 4]');
  checkThrows(
      'list each bad element indexed',
      () => plain.fromJson<Sample>({
            'items': [
              {'id': 1},
              'bad',
            ]
          }),
      match: (error) => error is FormatException && error.message.contains('items[1]'));

  check('forceValue null over input', plain.fromJson<Sample>({'forced': 3}).forced == null);
  check('forceValue null over onNullValue', plain.fromJson<Sample>({}).forced == null);
  check('forceValue false over input', plain.fromJson<Sample>({'ignored': true}).ignored == false);

  check('values override null skips onNullValue',
      plain.fromJson<Sample>({}, values: {'id': null}).id == null);
  check('values override skips convert',
      plain.fromJson<Sample>({'flag': true}, values: {'flag': 9}).flag == 9);

  check(
      'whole-list convert points',
      plain.fromJson<Sample>({
            'points': [
              [1, 2],
              [3, 4],
            ]
          }).points?.length ==
          2);
  check('map-aware convert summary',
      plain.fromJson<Sample>({'text': 'hi', 'suffix': 'x'}).summary == 'hi:x');
  check('map-aware convert missing text', plain.fromJson<Sample>({'suffix': 'x'}).summary == 'missing:x');

  final out = plain.toJson(
    plain.fromJson<Sample>({'legacy_id': 1, 'legacy_name': 'n', 'flag': true}),
    options: EncodeOptions(
      include: [
        const DogFieldRef<Sample>('id'),
        const DogFieldRef<Sample>('name'),
        const DogFieldRef<Sample>('flag'),
      ],
    ),
  );
  check('toJson include only', out.keys.toList().toString() == '[id, name, flag]');
  check('toJson values', out['id'] == 1 && out['name'] == 'n' && out['flag'] == 1);

  final renamed = plain.toJson(
    plain.fromJson<Sample>({'legacy_id': 1, 'legacy_name': 'n', 'flag': true}),
    options: EncodeOptions(
      include: [
        const DogFieldRef<Sample>('id'),
        const DogFieldRef<Sample>('name'),
        const DogFieldRef<Sample>('flag'),
      ],
    ),
    encodeAs: {'id': 'item_id'},
  );
  check('encodeAs renames id', renamed['item_id'] == 1 && !renamed.containsKey('id'));

  final included = plain.toJson(
    plain.fromJson<Sample>({'legacy_id': 2, 'legacy_name': 'n', 'flag': true}),
    options: EncodeOptions(
      include: [const DogFieldRef<Sample>('id')],
      rename: {const DogFieldRef<Sample>('id'): 'item_id'},
      also: {
        const DogFieldRef<Sample>('id'): ['section_category_id'],
      },
    ),
  );
  check(
      'EncodeOptions field refs',
      included['item_id'] == 2 &&
          included['section_category_id'] == 2 &&
          !included.containsKey('name'));

  check('JsonKey<int> is JsonKey', const JsonKey<int>(aliases: ['a']) is JsonKey);
  check('hasFixedValue null', const JsonKey<int>(forceValue: null).hasFixedValue());
  check('hasFixedValue unset', !const JsonKey<int>().hasFixedValue());
  check('falseValue typed bool', JsonConversions.falseValue(const {}) == false);
  check('zero typed int', JsonConversions.zero(const {}) == 0);

  checkThrows('unregistered type', () => DogModelCodec(engine: DogEngine()).fromJson<Sample>({}),
      match: (error) => error is StateError && error.message.contains('Sample'));

  if (failures == 0) {
    print('\nAll edge cases passed.');
  } else {
    print('\n$failures failure(s).');
    throw StateError('$failures json key edge case(s) failed');
  }
}
