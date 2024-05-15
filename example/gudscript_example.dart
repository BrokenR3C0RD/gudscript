//  Copyright 2024 MasterR3C0RD
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

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
