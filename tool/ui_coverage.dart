// UI coverage report for the chat SDK (informational only; no CI gate).
//
// Usage:
//   flutter test --coverage
//   dart run tool/ui_coverage.dart [coverage/lcov.info] [--all]
//
// Reports line coverage for lib/src/views/, lib/src/widgets/, and
// lib/src/res/theme/. Does not exit with failure unless --min=N is passed.

import 'dart:io';

const _include = [
  'lib/src/views/',
  'lib/src/widgets/',
  'lib/src/res/theme/',
];

void main(List<String> args) {
  final lcovPath = args.firstWhere(
    (a) => !a.startsWith('--'),
    orElse: () => 'coverage/lcov.info',
  );
  final minArg = args.cast<String?>().firstWhere(
        (a) => a != null && a.startsWith('--min='),
        orElse: () => null,
      );
  final min = minArg != null ? double.parse(minArg.substring(6)) : null;
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
    if (!_include.any(path.startsWith)) continue;
    final ignored = _ignoredLines(path);
    if (ignored == null) continue;
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

  for (final dir in _include) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final path = f.path;
      if (!path.endsWith('.dart') || hits.containsKey(path)) continue;
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

  for (final prefix in _include) {
    final prefixRows = rows.where((r) => r.path.startsWith(prefix));
    var pFound = 0;
    var pHit = 0;
    for (final r in prefixRows) {
      pFound += r.found;
      pHit += r.hit;
    }
    if (pFound == 0) continue;
    final pct = pHit * 100 / pFound;
    stdout.writeln(
      '\n${prefix.padRight(24)} ${pct.toStringAsFixed(2)}% ($pHit/$pFound)',
    );
  }

  final total = found == 0 ? 100.0 : hit * 100 / found;
  stdout.writeln(
    '\nUI line coverage (combined): ${total.toStringAsFixed(2)}% ($hit/$found)',
  );

  if (min != null && total + 1e-9 < min) {
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
