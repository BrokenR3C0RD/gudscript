import 'dart:io';

import 'package:gudscript/src/error.dart';
import 'package:gudscript/src/lexer.dart';
import 'package:gudscript/src/parser.dart';

void main() {
  final file = File('test.gud');
  final string = file.readAsStringSync();

  print('[*] Input:\n$string\n');
  try {
    final tokens = Lexer.fromString(string, url: file.uri).tokenize().toList();
    print('[*] Tokens:\n');
    print(tokens.join('\n'));
    final result = Parser(tokens).statement();
    print('[*] AST:\n$result');
  } on SyntaxError catch (e) {
    stderr.writeln(e.toString(color: true));
  }
}
