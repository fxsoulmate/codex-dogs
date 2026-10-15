import 'package:build/build.dart';
import 'package:lyell_gen/lyell_gen.dart';
import 'package:path/path.dart' as path;

/// Determines generated Dart paths before build_runner creates its asset graph.
class DogsOutputLayout {
  final String? directory;

  /// When true with [directory], converter files are written flat as
  /// `lib/<directory>/<path_with_underscores>.conv.g.dart` instead of nesting.
  final bool flat;

  const DogsOutputLayout({this.directory, this.flat = false});

  factory DogsOutputLayout.fromOptions(BuilderOptions options) {
    final value = options.config['output_directory'];
    final flat = options.config['output_flat'] == true;
    if (value == null) {
      if (flat) {
        throw ArgumentError.value(
            flat, 'output_flat', 'Requires output_directory to be set');
      }
      return const DogsOutputLayout();
    }
    if (value is! String ||
        value.isEmpty ||
        value.contains('\\') ||
        value.contains(':') ||
        path.posix.isAbsolute(value) ||
        value.split('/').any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
      throw ArgumentError.value(
          value, 'output_directory', 'Expected a relative directory below lib');
    }
    return DogsOutputLayout(directory: value, flat: flat);
  }

  AssetId converterAsset(AssetId input) {
    final directory = this.directory;
    if (directory == null) return input.changeExtension('.conv.g.dart');
    if (!input.path.startsWith('lib/')) {
      throw ArgumentError.value(input.path, 'input', 'Relocated models must be under lib');
    }
    if (!flat) {
      return AssetId(input.package, 'lib/$directory/${input.path.substring(4)}')
          .changeExtension('.conv.g.dart');
    }
    return AssetId(input.package, 'lib/$directory/${flatStem(input)}.conv.g.dart');
  }

  /// `lib/city_page/city_model.dart` → `city_page_city_model`
  String flatStem(AssetId input) {
    final relative = input.path.substring(4);
    if (!relative.endsWith('.dart')) {
      throw ArgumentError.value(input.path, 'input', 'Expected a .dart library under lib');
    }
    return relative.substring(0, relative.length - '.dart'.length).replaceAll('/', '_');
  }

  String reactorFileName() => directory == null ? 'dogs.g.dart' : '$directory/dogs.g.dart';

  Map<String, List<String>> converterBuildExtensions() {
    if (directory == null) return {'.dart': ['.conv.g.dart']};
    if (!flat) {
      return {'^lib/{{}}.dart': ['lib/$directory/{{}}.conv.g.dart']};
    }
    // Fixed-depth segment captures so each piece is slash-free and can be joined with `_`.
    return {
      for (var depth = 1; depth <= 8; depth++)
        '^lib/${List.generate(depth, (i) => '{{s$i}}').join('/')}.dart': [
          'lib/$directory/${List.generate(depth, (i) => '{{s$i}}').join('_')}.conv.g.dart',
        ],
    };
  }

  void validateDescriptor(SubjectDescriptor descriptor) {
    if (descriptor.meta.containsKey('outputDirectory') &&
        descriptor.meta['outputDirectory'] != directory) {
      throw StateError(
        'Configure output_directory identically for dogs_descriptors, dogs_bindings and '
        'dogs_reactor. Converter ${descriptor.uri} uses '
        '${descriptor.meta['outputDirectory']}, but dogs_reactor uses $directory.',
      );
    }
  }
}
