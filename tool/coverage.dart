// Business-logic coverage gate for the chat SDK.
//
// Usage (normally via tool/coverage.sh):
//   dart run tool/coverage.dart [coverage/lcov.info] [--min=100] [--all]
//
// - Reads the lcov file produced by `flutter test --coverage`.
// - Keeps only in-scope files (see [_include] / [_exclude]); UI and
//   platform-plugin-only code is excluded as agreed in the test plan.
// - Honors `// coverage:ignore-line`, `// coverage:ignore-start` /
//   `// coverage:ignore-end` and `// coverage:ignore-file` in the sources,
//   so the result does not depend on the Flutter version's own support.
// - Prints per-file coverage (worst first) and exits with code 1 when the
//   total is below `--min`. `--all` lists fully covered files too.
//
// No external tools (lcov/genhtml) are required.

import 'dart:io';

/// Folders whose code is held to the coverage threshold.
const _include = [
  'lib/src/models/',
  'lib/src/data/',
  'lib/src/repositories/',
  'lib/src/view_models/',
  'lib/src/controllers/',
  'lib/src/utilities/',
  'lib/src/services/',
];

/// In-scope paths that are excluded anyway, with the reason.
const _exclude = {
  // Web-only implementation (dart:html), cannot run on the VM test runner.
  'lib/src/utilities/blob_html.dart',
};

void main(List<String> args) {
  final lcovPath =
      args.firstWhere((a) => !a.startsWith('--'), orElse: () => 'coverage/lcov.info');
  final min = double.parse(
    args
        .firstWhere((a) => a.startsWith('--min='), orElse: () => '--min=100')
        .substring(6),
  );
  final listAll = args.contains('--all');

  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('No $lcovPath. Run `flutter test --coverage` first.');
    exit(2);
  }

  final hits = _parseLcov(file.readAsLinesSync());
  final rows = <_Row>[];
  var found = 0;
  var hit = 0;

  for (final entry in hits.entries) {
    final path = entry.key;
    if (!_include.any(path.startsWith) || _exclude.contains(path)) continue;
    final ignored = _ignoredLines(path);
    if (ignored == null) continue; // coverage:ignore-file
    var f = 0;
    var h = 0;
    entry.value.forEach((line, count) {
      if (ignored.contains(line)) return;
      f++;
      if (count > 0) h++;
    });
    if (f == 0) continue;
    found += f;
    hit += h;
    rows.add(_Row(path, f, h));
  }

  // Files in scope that no test loaded at all count as 0%.
  for (final dir in _include) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final path = f.path;
      if (!path.endsWith('.dart') ||
          hits.containsKey(path) ||
          _exclude.contains(path)) {
        continue;
      }
      final lines = _executableEstimate(path);
      if (lines == 0) continue;
      found += lines;
      rows.add(_Row(path, lines, 0, unloaded: true));
    }
  }

  rows.sort((a, b) => a.percent.compareTo(b.percent));
  for (final r in rows) {
    if (!listAll && r.hit == r.found) continue;
    stdout.writeln(
      '${r.percent.toStringAsFixed(1).padLeft(6)}%  '
      '${'${r.hit}/${r.found}'.padLeft(11)}  ${r.path}'
      '${r.unloaded ? '  (never loaded, estimated)' : ''}',
    );
  }
  final total = found == 0 ? 100.0 : hit * 100 / found;
  stdout.writeln(
      '\nBusiness-logic line coverage: ${total.toStringAsFixed(2)}% ($hit/$found)');
  if (total + 1e-9 < min) {
    stderr.writeln('FAIL: below required ${min.toStringAsFixed(2)}%');
    exit(1);
  }
}

class _Row {
  _Row(this.path, this.found, this.hit, {this.unloaded = false});
  final String path;
  final int found;
  final int hit;
  final bool unloaded;
  double get percent => found == 0 ? 100 : hit * 100 / found;
}

/// path -> (line -> hit count)
Map<String, Map<int, int>> _parseLcov(List<String> lines) {
  final result = <String, Map<int, int>>{};
  Map<int, int>? current;
  final cwd = Directory.current.path;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      var path = line.substring(3);
      if (path.startsWith(cwd)) path = path.substring(cwd.length + 1);
      current = result.putIfAbsent(path, () => {});
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      final n = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      current[n] = (current[n] ?? 0) + c;
    } else if (line == 'end_of_record') {
      current = null;
    }
  }
  return result;
}

/// Line numbers excluded by ignore comments, or `null` for ignore-file.
Set<int>? _ignoredLines(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  final ignored = <int>{};
  var inBlock = false;
  final lines = f.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i];
    final n = i + 1;
    if (text.contains('coverage:ignore-file')) return null;
    if (text.contains('coverage:ignore-start')) inBlock = true;
    if (inBlock || text.contains('coverage:ignore-line')) ignored.add(n);
    if (text.contains('coverage:ignore-end')) inBlock = false;
  }
  return ignored;
}

/// Rough executable-line count for files no test imported (so they are not
/// silently skipped). Part files are loaded with their library, so they
/// normally appear in lcov; this mostly catches dead files.
int _executableEstimate(String path) {
  final lines = File(path).readAsLinesSync();
  if (lines.any((l) => l.startsWith('part of')) ||
      lines.any((l) => l.contains('coverage:ignore-file'))) {
    return 0;
  }
  return lines.where((l) {
    final t = l.trim();
    return t.isNotEmpty &&
        !t.startsWith('//') &&
        !t.startsWith('import ') &&
        !t.startsWith('export ') &&
        !t.startsWith('part ') &&
        t != '}' &&
        t != '{' &&
        t.endsWith(';');
  }).length;
}
