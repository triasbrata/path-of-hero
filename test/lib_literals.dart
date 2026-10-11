// The string literals of lib/'s Dart files, for the tests that read the UI's words from the source (guide_text_test,
// english_text_test). Not a test (no `_test.dart`).
import 'dart:io';

/// The string literals in Dart [source], each as its text with the interpolations left out ('Mulai ${n}' is "Mulai "),
/// comments skipped. Enough for this repo's code: a string over several lines isn't followed.
List<String> dartLiterals(String source) {
  final out = <String>[];
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    String? quote;
    final text = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quote == null) {
        if (line.startsWith('//', i)) break; // a comment after the code
        if (c == "'" || c == '"') {
          quote = c;
          text.clear();
        }
      } else if (c == r'\') {
        i++; // an escape: the next character is the string's
      } else if (c == r'$' && line.startsWith(r'${', i)) {
        var depth = 0; // an interpolation: skipped to its closing brace, any quotes in it with it
        for (i++; i < line.length; i++) {
          if (line[i] == '{') depth++;
          if (line[i] == '}' && --depth == 0) break;
        }
      } else if (c == r'$') {
        while (i + 1 < line.length && RegExp(r'\w').hasMatch(line[i + 1])) {
          i++;
        }
      } else if (c == quote) {
        out.add('$text');
        quote = null;
      } else {
        text.write(c);
      }
    }
  }
  return out;
}

/// lib/'s Dart files (it has no folders), by path, in name order.
List<File> libFiles() => [
      for (final f in Directory('lib').listSync().whereType<File>()) if (f.path.endsWith('.dart')) f,
    ]..sort((a, b) => a.path.compareTo(b.path));
