import 'dart:io';

import 'package:gudscript/src/lexer.dart';
import 'package:gudscript/src/parser.dart';

void main() {
  final file = File('test.gud');
  final string = file.readAsStringSync();

  print('[*] Input:');
  print(string);
  print('');
  final tokens = Lexer.fromString(string, url: file.uri).tokenize().toList();
  print('[*] Tokens:');
  print(tokens.join('\n'));
  print('');

  final watch = Stopwatch()..start();
  const count = 100000;
  for (var i = 0; i < count; i++) {
    final result = Parser(tokens).statement();
    if (i == 0) print(result);
  }
  watch.stop();
  print('Average parse time: ${watch.elapsedMilliseconds / count}ms');
}
