import "package:dogs_core/dogs_models.dart";
import "package:test/test.dart";

class Item {
  const Item({this.id, this.name, this.secret});

  final int? id;
  final String? name;
  final String? secret;
}

class Column {
  const Column({required this.name, required this.width, required this.isPinned});

  final String name;
  final double width;
  final bool isPinned;
}

class Table {
  const Table({required this.name, required this.columns});

  final String name;
  final List<Column> columns;
}

class Section {
  const Section({this.id, this.feeRate, this.nameKu});

  final int? id;
  final num? feeRate;
  final String? nameKu;
}

class Node {
  const Node({this.child, this.children});

  final Item? child;
  final List<Item>? children;
}

class Dual {
  const Dual({this.id});

  final int? id;
}

// Manual Model$-style refs (codegen emits these as Item$.id, etc.).
class Item$ {
  Item$._();
  static const id = DogFieldRef<Item>("id");
  static const name = DogFieldRef<Item>("name");
  static const secret = DogFieldRef<Item>("secret");
}

class Column$ {
  Column$._();
  static const name = DogFieldRef<Column>("name");
  static const width = DogFieldRef<Column>("width");
  static const isPinned = DogFieldRef<Column>("is_pinned");
}

class Section$ {
  Section$._();
  static const id = DogFieldRef<Section>("id");
  static const feeRate = DogFieldRef<Section>("fee_rate");
  static const nameKu = DogFieldRef<Section>("name_ku");
}

class Dual$ {
  Dual$._();
  static const id = DogFieldRef<Dual>("id");
}

void registerModel<T>(DogEngine engine, DogStructure<T> structure) {
  engine.registerStructure(structure, emitChangeToStream: false);
  engine.registerAssociatedConverter(DogStructureConverterImpl<T>(structure),
      emitChangeToStream: false);
}

DogStructure<Item> itemStructure({JsonModel meta = const JsonModel()}) => DogStructure<Item>(
      "Item",
      StructureConformity.basic,
      [
        DogStructureField.int("id", optional: true),
        DogStructureField.string("name", optional: true),
        DogStructureField.string("secret", optional: true),
      ],
      [meta],
      ObjectFactoryStructureProxy<Item>(
        (values) => Item(id: values[0], name: values[1], secret: values[2]),
        [(v) => v.id, (v) => v.name, (v) => v.secret],
        (v) => [v.id, v.name, v.secret],
      ),
    );

DogStructure<Column> columnStructure() => DogStructure<Column>(
      "Column",
      StructureConformity.basic,
      [
        DogStructureField.string("name"),
        DogStructureField.double("width"),
        DogStructureField.bool("is_pinned", annotations: const [
          JsonKey(aliases: ["isPinned", "isPin", "is_pinned", "is_pin"], name: "isPinned"),
        ]),
      ],
      const [
        JsonModel(outputKeys: ["name", "width", "is_pinned"])
      ],
      ObjectFactoryStructureProxy<Column>(
        (values) => Column(name: values[0], width: values[1], isPinned: values[2]),
        [(v) => v.name, (v) => v.width, (v) => v.isPinned],
        (v) => [v.name, v.width, v.isPinned],
      ),
    );

DogStructure<Table> tableStructure() => DogStructure<Table>(
      "Table",
      StructureConformity.basic,
      [
        DogStructureField.string("name"),
        DogStructureField.create<Column>("columns", iterable: IterableKind.list),
      ],
      const [
        JsonModel(outputKeys: ["name", "columns"])
      ],
      ObjectFactoryStructureProxy<Table>(
        (values) => Table(name: values[0], columns: values[1]),
        [(v) => v.name, (v) => v.columns],
        (v) => [v.name, v.columns],
      ),
    );

DogStructure<Section> sectionStructure() => DogStructure<Section>(
      "Section",
      StructureConformity.basic,
      [
        DogStructureField.int("id", optional: true, annotations: const [
          JsonKey(aliases: ["id", "section_category_id"], encodeAlso: ["section_category_id"]),
        ]),
        DogStructureField.create<num>("fee_rate", optional: true),
        DogStructureField.string("name_ku", optional: true),
      ],
      const [
        JsonModel(outputKeys: ["id", "fee_rate"])
      ],
      ObjectFactoryStructureProxy<Section>(
        (values) => Section(id: values[0], feeRate: values[1], nameKu: values[2]),
        [(v) => v.id, (v) => v.feeRate, (v) => v.nameKu],
        (v) => [v.id, v.feeRate, v.nameKu],
      ),
    );

DogStructure<Node> nodeStructure() => DogStructure<Node>(
      "Node",
      StructureConformity.basic,
      [
        DogStructureField.create<Item>("child", optional: true),
        DogStructureField.create<Item>("children", optional: true, iterable: IterableKind.list),
      ],
      const [JsonModel()],
      ObjectFactoryStructureProxy<Node>(
        (values) => Node(child: values[0], children: values[1]),
        [(v) => v.child, (v) => v.children],
        (v) => [v.child, v.children],
      ),
    );

DogStructure<Dual> dualStructure() => DogStructure<Dual>(
      "Dual",
      StructureConformity.basic,
      [
        DogStructureField.int("id", optional: true, annotations: const [
          JsonKey(encodeAlso: ["section_category_id", "category_id"]),
        ]),
      ],
      const [JsonModel()],
      ObjectFactoryStructureProxy<Dual>(
        (values) => Dual(id: values[0]),
        [(v) => v.id],
        (v) => [v.id],
      ),
    );

({DogEngine engine, DogModelCodec codec}) fixture() {
  final engine = DogEngine();
  registerModel(engine, itemStructure(meta: const JsonModel(outputKeys: ["id", "name"])));
  registerModel(engine, columnStructure());
  registerModel(engine, tableStructure());
  registerModel(engine, sectionStructure());
  registerModel(engine, nodeStructure());
  registerModel(engine, dualStructure());
  return (engine: engine, codec: DogModelCodec(engine: engine));
}

void main() {
  group("DogFieldRef", () {
    test("equality is by structure name", () {
      expect(Item$.id, equals(const DogFieldRef<Item>("id")));
      expect(Item$.id, equals(const DogFieldRef<Section>("id")));
      expect(Item$.id, isNot(equals(Item$.name)));
      expect({Item$.id: "item_id"}[const DogFieldRef<Item>("id")], "item_id");
    });

    test("fieldName accepts String and DogFieldRef only", () {
      expect(EncodeOptions.fieldName(Item$.id), "id");
      expect(EncodeOptions.fieldName("name_ku"), "name_ku");
      expect(() => EncodeOptions.fieldName(1), throwsArgumentError);
    });
  });

  group("default recursive encode", () {
    test("ItemModel default id and nested TableModel columns become maps", () {
      final (:codec, engine: _) = fixture();
      expect(codec.toJson(const Item(id: 7, name: "x", secret: "no")), {"id": 7, "name": "x"});

      final table = Table(
        name: "city",
        columns: const [Column(name: "id", width: 150, isPinned: true)],
      );
      final json = codec.toJson(table);
      expect(json["name"], "city");
      expect(json["columns"], [
        {"name": "id", "width": 150.0, "isPinned": true},
      ]);
    });

    test("null nested model and empty list encode cleanly", () {
      final (:codec, engine: _) = fixture();
      expect(codec.toJson(const Node()), {"child": null, "children": null});
      expect(codec.toJson(const Node(children: [])), {"child": null, "children": <Map>[]});
    });

    test("deep nesting encodes recursively", () {
      final (:codec, engine: _) = fixture();
      final json = codec.toJson(const Node(
        child: Item(id: 1, name: "a"),
        children: [Item(id: 2, name: "b"), Item(id: 3, name: "c")],
      ));
      expect(json["child"]["id"], 1);
      expect(json["children"][1]["name"], "c");
    });

    test("aliases stay decode-only on encode", () {
      final (:codec, engine: _) = fixture();
      final column = codec.fromJson<Column>({
        "name": "n",
        "width": 1.0,
        "isPin": true,
      });
      final json = codec.toJson(column);
      expect(json.keys.toList(), ["name", "width", "isPinned"]);
      expect(json.containsKey("isPin"), isFalse);
      expect(json.containsKey("is_pinned"), isFalse);
      expect(json.containsKey("is_pin"), isFalse);
    });
  });

  group("encodeAlso annotation", () {
    test("SectionCategoryModel writes id and section_category_id", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(const Section(id: 3, feeRate: 1.5)),
        {"id": 3, "section_category_id": 3, "fee_rate": 1.5},
      );
    });

    test("multiple encodeAlso keys and skip duplicate of primary", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(const Dual(id: 9)),
        {"id": 9, "section_category_id": 9, "category_id": 9},
      );
      expect(
        codec.toJson(const Dual(id: 9), options: EncodeOptions(rename: {Dual$.id: "id"})),
        {"id": 9, "section_category_id": 9, "category_id": 9},
      );
    });

    test("rename primary keeps encodeAlso extras", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(const Section(id: 3, feeRate: 2), encodeAs: {"id": "category_id"}),
        {"category_id": 3, "section_category_id": 3, "fee_rate": 2},
      );
    });
  });

  group("EncodeOptions with Model\$ field refs", () {
    test("include + rename via SectionCategoryModel\$-style refs", () {
      final (:codec, engine: _) = fixture();
      final json = codec.toJson(
        const Section(id: 3, feeRate: 9, nameKu: "ku"),
        options: EncodeOptions(
          include: [Section$.id, Section$.nameKu],
          rename: {Section$.id: "item_id"},
        ),
      );
      expect(json, {"item_id": 3, "section_category_id": 3, "name_ku": "ku"});
      expect(json.containsKey("fee_rate"), isFalse);
    });

    test("string keys work the same as DogFieldRef", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(const Item(id: 7, name: "n"), encodeAs: {"id": "item_id"}),
        {"item_id": 7, "name": "n"},
      );
      expect(
        codec.toJson(
          const Item(id: 7, name: "n"),
          options: EncodeOptions(rename: {Item$.id: "item_id"}),
        ),
        {"item_id": 7, "name": "n"},
      );
    });

    test("exclude removes fields after outputKeys", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(
          const Item(id: 1, name: "n", secret: "s"),
          options: EncodeOptions(exclude: [Item$.name]),
        ),
        {"id": 1},
      );
    });

    test("include replaces outputKeys whitelist for the call", () {
      final (:codec, engine: _) = fixture();
      // secret is outside JsonModel.outputKeys but include can select it.
      expect(
        codec.toJson(
          const Item(id: 1, name: "n", secret: "s"),
          options: EncodeOptions(include: [Item$.secret]),
        ),
        {"secret": "s"},
      );
    });

    test("exclude wins over include", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(
          const Item(id: 1, name: "n"),
          options: EncodeOptions(
            include: [Item$.id, Item$.name],
            exclude: [Item$.name],
          ),
        ),
        {"id": 1},
      );
    });

    test("options.also dual-writes per call without annotation", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(
          const Item(id: 5, name: "n"),
          options: EncodeOptions(also: {
            Item$.id: ["item_id", "product_id"],
          }),
        ),
        {"id": 5, "item_id": 5, "product_id": 5, "name": "n"},
      );
    });

    test("extras merge and overwrite colliding keys", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(
          const Item(id: 1, name: "n"),
          options: EncodeOptions(extras: {"name": "over", "extra": true}),
        ),
        {"id": 1, "name": "over", "extra": true},
      );
      expect(
        codec.toJson(const Item(id: 1, name: "n"), extras: {"x": 1}),
        {"id": 1, "name": "n", "x": 1},
      );
    });

    test("encodeAs merges with options.rename; later encodeAs wins on clash", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.toJson(
          const Item(id: 1, name: "n"),
          options: EncodeOptions(rename: {Item$.id: "a"}),
          encodeAs: {"id": "b"},
        ),
        {"b": 1, "name": "n"},
      );
    });
  });

  group("nested rename / forType", () {
    test("parent rename applies while walking nested columns", () {
      final (:codec, engine: _) = fixture();
      final table = Table(
        name: "t",
        columns: const [Column(name: "c", width: 10, isPinned: false)],
      );
      final json = codec.toJson(
        table,
        options: EncodeOptions(rename: {Column$.isPinned: "is_pin"}),
      );
      expect(json["columns"].single, {"name": "c", "width": 10.0, "is_pin": false});
    });

    test("forType can include/exclude nested fields only", () {
      final (:codec, engine: _) = fixture();
      final table = Table(
        name: "t",
        columns: const [Column(name: "c", width: 10, isPinned: true)],
      );
      final json = codec.toJson(
        table,
        options: EncodeOptions(
          forType: {
            Column: EncodeOptions(
              include: [Column$.name, Column$.isPinned],
              rename: {Column$.isPinned: "isPin"},
            ),
          },
        ),
      );
      expect(json["name"], "t");
      expect(json["columns"].single, {"name": "c", "isPin": true});
    });

    test("Column default JsonKey.name isPinned; encodeAs can pick is_pinned / isPin / is_pin", () {
      final (:codec, engine: _) = fixture();
      const column = Column(name: "c", width: 1, isPinned: true);
      expect(codec.toJson(column)["isPinned"], isTrue);
      expect(codec.toJson(column, encodeAs: {"is_pinned": "is_pinned"})["is_pinned"], isTrue);
      expect(codec.toJson(column, encodeAs: {"is_pinned": "isPin"})["isPin"], isTrue);
      expect(codec.toJson(column, encodeAs: {"is_pinned": "is_pin"})["is_pin"], isTrue);
    });

    test("JsonKey.name decode falls back to aliases when named key is absent", () {
      final (:codec, engine: _) = fixture();
      expect(
        codec.fromJson<Column>({"name": "n", "width": 1.0, "is_pin": true}).isPinned,
        isTrue,
      );
      expect(
        codec.fromJson<Column>({"name": "n", "width": 1.0, "isPinned": false}).isPinned,
        isFalse,
      );
    });
  });

  group("validation edge cases", () {
    test("unknown include / exclude throw; nested-only rename/also are ignored here", () {
      final (:codec, engine: _) = fixture();
      const item = Item(id: 1, name: "n");
      expect(
        () => codec.toJson(item, options: EncodeOptions(include: ["nope"])),
        throwsA(isA<ArgumentError>().having((e) => e.message, "m", contains("Unknown field"))),
      );
      expect(
        () => codec.toJson(item, options: EncodeOptions(exclude: [const DogFieldRef<Item>("x")])),
        throwsArgumentError,
      );
      // Typo rename does not throw at this level (may target nested fields).
      expect(
        codec.toJson(item, options: EncodeOptions(rename: {"x": "y"})),
        {"id": 1, "name": "n"},
      );
      expect(
        codec.toJson(item, options: EncodeOptions(also: {"x": ["y"]})),
        {"id": 1, "name": "n"},
      );
    });

    test("null scalars remain null keys when included", () {
      final (:codec, engine: _) = fixture();
      expect(codec.toJson(const Item()), {"id": null, "name": null});
    });

    test("round-trip fromJson aliases then toJson with encodeAs", () {
      final (:codec, engine: _) = fixture();
      final section = codec.fromJson<Section>({
        "section_category_id": 11,
        "fee_rate": 0.2,
      });
      expect(section.id, 11);
      expect(
        codec.toJson(section, options: EncodeOptions(rename: {Section$.id: "item_id"})),
        {"item_id": 11, "section_category_id": 11, "fee_rate": 0.2},
      );
    });
  });
}
