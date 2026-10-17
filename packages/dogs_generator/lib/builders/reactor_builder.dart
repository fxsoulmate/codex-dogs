import 'dart:async';

import 'package:build/build.dart';
import 'package:lyell_gen/lyell_gen.dart';
import 'package:recase/recase.dart';

import '../settings.dart';
import '../output_layout.dart';

class DogReactorBuilder extends SubjectReactorBuilder {
  final DogsOutputLayout outputLayout;

  DogReactorBuilder({this.outputLayout = const DogsOutputLayout()})
      : super('dogs', outputLayout.reactorFileName());

  String packageName = "unnamed";
  bool isLibrary = false;
  late BuildStep step;

  @override
  Future build(BuildStep buildStep) async {
    step = buildStep;
    packageName = buildStep.inputId.package;
    var settings = await DogsGeneratorSettings.load(buildStep);
    isLibrary = settings.isLibrary;
    await super.build(buildStep);
  }

  @override
  FutureOr<void> buildReactor(List<SubjectDescriptor> descriptors, SubjectCodeContext code) async {
    code.additionalImports.add(AliasImport.root("package:dogs_core/dogs_core.dart"));

    // Never overwrite a populated dogs.g.dart with linkAll([]) — that is the
    // failure mode when dogs_descriptors did not run (build_extensions mismatch,
    // stale build cache, or analyzer/experiment errors on model files).
    if (descriptors.isEmpty && outputLayout.directory != null) {
      throw StateError(
        'dogs_reactor found 0 converters for output_directory='
        '${outputLayout.directory}. Refusing to write empty GeneratedModelsPlugin.\n'
        'Fix: run tool/regen_dogs.sh (or: dart run build_runner clean && '
        'dart run build_runner build). Also ensure dogs_generator build.yaml '
        'dogs_descriptors.build_extensions match DogsOutputLayout '
        '(flat lib/generated/dogs/*.conv.g.dart).',
      );
    }

    List<String> descriptorNames = [];
    for (var descriptor in descriptors) {
      outputLayout.validateDescriptor(descriptor);
      if (descriptor.meta.containsKey('outputDirectory') &&
          !await step.canRead(AssetId.resolve(Uri.parse(descriptor.uri)))) {
        throw StateError(
          'Cannot read converter ${descriptor.uri}. Configure output_directory identically for '
          'dogs_descriptors, dogs_bindings and dogs_reactor.',
        );
      }
      var constructedNames = ((descriptor.meta["constructedNames"] ?? []) as List).cast<String>();
      var variableNames = ((descriptor.meta["variableNames"] ?? []) as List).cast<String>();
      for (var name in constructedNames) {
        try {
          var type = await getDartType(step, descriptor.uri, name);
          descriptorNames.add("${code.cachedCounter.get(type)}()");
        } on ArgumentError catch (e, st) {
          // One broken converter must not wipe dogs.g.dart — skip and warn.
          log.warning(
            'dogs_reactor: skip $name from ${descriptor.uri}: $e\n$st',
          );
        }
      }
      for (var name in variableNames) {
        var alias = code.cachedCounter.getImportAlias(descriptor.uri);
        descriptorNames.add("${alias.prefix}.$name");
      }
      code.codeBuffer.writeln("export '${descriptor.uri}';");
    }
    var converterNameArr = "[${descriptorNames.join(", ")}]";
    if (!isLibrary) {
      code.codeBuffer.writeln("""
       
DogPlugin GeneratedModelsPlugin() => (engine) {
  engine.linkAll($converterNameArr);
};""");
    } else {
      var fieldName = ReCase("$packageName converters").camelCase;
      var funcName = ReCase("$packageName Generated Models Plugin").pascalCase;
      code.codeBuffer.writeln("""
      
final $fieldName = <DogLinkable>$converterNameArr;
      
DogPlugin $funcName() => (engine) {
  engine.linkAll($fieldName);
};""");
      print("Wrote: ${code.codeBuffer}");
    }
  }
}
