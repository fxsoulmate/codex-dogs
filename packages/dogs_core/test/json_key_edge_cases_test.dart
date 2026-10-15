import "package:test/test.dart";
import "dart:io";

void main() {
  test("JsonKey edge cases", () {
    final result = Process.runSync(
      "dart",
      ["run", "tool/json_key_edge_cases.dart"],
      workingDirectory: Directory.current.path.endsWith("dogs_core")
          ? Directory.current.path
          : "packages/dogs_core",
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0, reason: "json key edge cases failed");
  }, timeout: const Timeout(Duration(minutes: 2)));
}
