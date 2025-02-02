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

import 'package:gudscript/src/error.dart';
import 'package:gudscript/src/tokens.dart';
import 'package:source_span/source_span.dart';

const _spaces = {
  0x0009, // TAB
  0x000B, // VT
  0x000C, // FF
  0x0020, // SP
  0x00A0, // NBSP
  0x1680, // Ogham Space Mark
  0x2000, // 2/Em Quad
  0x2001, // Em Quad
  0x2002, // 2/Em Space
  0x2003, // Em Space
  0x2004, // 3/Em Space
  0x2005, // 4/Em Space
  0x2006, // 6/Em Space
  0x2007, // Figure Space
  0x2008, // Punctuation Space
  0x2009, // Thin Space
  0x200A, // Hair Space
  0x202F, // NNBSP
  0x205F, // MMSP
  0x3000, // Ideographic Space
  0xFEFF, // ZWNSP
};

const _newlines = {
  0x000A, // LF
  0x000D, // CR
  0x2028, // LS
  0x2029, // PS
};

const upperA = 0x41;
const upperF = 0x46;
const upperZ = 0x5A;

const lowerA = 0x61;
const lowerF = 0x66;
const lowerZ = 0x7A;

const zero = 0x30;
const one = 0x31;
const nine = 0x39;

const dollar = 0x24;
const underscore = 0x5F;
const backslash = 0x5C;

class Lexer {
  final SourceFile source;
  int offset = 0;

  Lexer(List<int> codeUnits, {Object? url})
      : source = SourceFile.decoded(codeUnits, url: url);
  Lexer.fromString(String source, {Object? url})
      : source = SourceFile.fromString(source, url: url);

  int get current => source.codeUnits[offset];
  String get currentChar => String.fromCharCode(current);

  int? get peek => source.codeUnits.elementAtOrNull(offset + 1);
  String? get peekChar {
    final peek = this.peek;
    return peek != null ? String.fromCharCode(peek) : null;
  }

  bool get _eos => offset >= source.codeUnits.length;
  bool get done => offset > source.codeUnits.length;

  FileSpan spanFrom(int start) => source.span(start, offset);

  int count(bool Function(int) test) =>
      source.codeUnits.skip(offset).takeWhile(test).length;

  String? substring(int length, {int offset = 0}) {
    if (this.offset + offset + length > source.codeUnits.length) return null;
    return String.fromCharCodes(
        source.codeUnits.skip(this.offset + offset).take(length));
  }

  String eatWhile(bool Function(int) test) {
    final str =
        String.fromCharCodes(source.codeUnits.skip(offset).takeWhile(test));
    offset += str.length;
    return str;
  }

  bool testSpace(int codeUnit) => _spaces.contains(codeUnit);

  bool testUpperAlpha(int codeUnit) => codeUnit >= upperA && codeUnit <= upperZ;
  bool testLowerAlpha(int codeUnit) => codeUnit >= lowerA && codeUnit <= lowerZ;
  bool testAlpha(int codeUnit) =>
      testUpperAlpha(codeUnit) || testLowerAlpha(codeUnit);
  bool testBase10(int codeUnit) => codeUnit >= zero && codeUnit <= nine;
  bool testBase2(int codeUnit) => codeUnit == zero || codeUnit == one;
  bool testBase16(int codeUnit) =>
      testBase10(codeUnit) ||
      (codeUnit >= upperA && codeUnit <= upperF) ||
      (codeUnit >= lowerA && codeUnit <= lowerF);
  // A-Za-z0-9_$
  bool testIdentifier(int codeUnit) =>
      testAlpha(codeUnit) ||
      testBase10(codeUnit) ||
      codeUnit == dollar ||
      codeUnit == underscore;

  // Parsers start here
  Token? newline() {
    if (!Newline.valid.contains(currentChar)) return null;

    final start = offset;
    if (currentChar == '\r' && peekChar == '\n') {
      offset += 2;
      return Newline('\r\n', spanFrom(start));
    } else {
      offset++;
      return Newline('\r\n', spanFrom(start));
    }
  }

  Token? identifier() {
    if (testBase10(current)) return null;

    final start = offset;
    final id = eatWhile(testIdentifier);
    if (id.isEmpty) return null;

    final span = spanFrom(start);
    if (Keyword.keywords.contains(id)) {
      return Keyword(id, span);
    } else {
      return Identifier(id, span);
    }
  }

  Token? comment() {
    if (currentChar != '/' || peekChar != '/') return null;

    final start = offset;
    offset += 2;

    final comment = eatWhile((char) => !_newlines.contains(char));
    return Comment(comment, spanFrom(start));
  }

  Token? char() {
    final char = currentChar;
    if (!Char.valid.contains(char)) return null;

    return Char(char, spanFrom(offset++));
  }

  Token? multiChar() {
    final str = substring(2);
    if (str == null || !MultiChar.valid.contains(str)) return null;

    return MultiChar(str, spanFrom((offset += 2) - 2));
  }

  bool _getDigitsRadix(StringBuffer buffer, bool Function(int) digitTest) {
    if (!digitTest(current)) return false;

    do {
      buffer.write(eatWhile(digitTest));

      if (current == underscore) {
        if (peek == null || !digitTest(peek!)) {
          if (peek == underscore) {
            final underscores = count((char) => char == underscore);
            throw SyntaxError(
              'only one underscore can be used as a numeric separator',
              source.span(offset, offset + underscores),
              primaryLabel: 'only one allowed',
            );
          } else {
            throw SyntaxError(
                'number literals cannot end with a numeric separator',
                spanFrom(offset),
                primaryLabel: 'remove this');
          }
        } else {
          offset += 1;
        }
      }
    } while (digitTest(current));

    return true;
  }

  Token _radixLiteral(bool Function(int) digitTest, NumberLiteralType type) {
    final start = offset;
    offset += 2;

    final buffer = StringBuffer();
    if (!_getDigitsRadix(buffer, digitTest)) {
      throw SyntaxError(
          'invalid base-${type.radix} literal', source.span(start, start));
    }

    return NumberLiteral(buffer.toString(), spanFrom(start), type);
  }

  Token _decLiteral() {
    final start = offset;
    final buffer = StringBuffer();
    _getDigitsRadix(buffer, testBase10);

    if (currentChar != '.' && currentChar.toLowerCase() != 'e') {
      return NumberLiteral(
          buffer.toString(), spanFrom(start), NumberLiteralType.integer);
    }

    if (currentChar == '.') {
      buffer.write('.');
      offset += 1;
      if (!_getDigitsRadix(buffer, testBase10)) {
        throw SyntaxError(
          'invalid decimal literal',
          spanFrom(offset),
        );
      }
    }

    if (currentChar.toLowerCase() == 'e') {
      buffer.write('e');
      if (currentChar == '-') {
        buffer.write('-');
        offset++;
      } else if (currentChar == '+') {
        offset++;
      }

      if (!_getDigitsRadix(buffer, testBase10)) {
        throw SyntaxError(
          'invalid decimal literal',
          spanFrom(offset),
        );
      }
    }

    return NumberLiteral(
        buffer.toString(), spanFrom(start), NumberLiteralType.decimal);
  }

  Token? number() {
    if (!testBase10(current)) return null;

    return switch (substring(2)) {
      '0b' => _radixLiteral(testBase2, NumberLiteralType.binary),
      '0x' => _radixLiteral(testBase16, NumberLiteralType.hex),
      _ => _decLiteral()
    };
  }

  Token? _plaintext(int quote) {
    if (_eos || current == quote || current == dollar) return null;

    final start = offset;
    final buffer = StringBuffer();
    do {
      if (current == backslash) {
        String? char;
        switch (peekChar) {
          case _ when peek == quote:
            char = String.fromCharCode(quote);
            offset += 2;
          case r'$':
            char = r'$';
            offset += 2;
          case 'f':
            char = '\f';
            offset += 2;
          case 'n':
            char = '\n';
            offset += 2;
          case 'r':
            char = '\r';
            offset += 2;
          case 't':
            char = '\t';
            offset += 2;
          case 'v':
            char = '\v';
            offset += 2;
          case '0':
            char = String.fromCharCode(0);
            offset += 2;
          case 'c':
            final escapeCode = peek;
            if (escapeCode == null || !testAlpha(escapeCode)) break;
            char = String.fromCharCode(escapeCode % 26);
            offset += 3;
          case 'x':
            final escapeCode = substring(2, offset: 2);
            if (escapeCode == null) break;
            final charCode = int.tryParse(escapeCode, radix: 16);
            if (charCode == null) break;
            char = String.fromCharCode(charCode);
            offset += 4;
          case 'u':
            final escapeCode = substring(4, offset: 2);
            if (escapeCode == null) break;
            final charCode = int.tryParse(escapeCode, radix: 16);
            if (charCode == null) break;
            char = String.fromCharCode(charCode);
            offset += 6;
        }

        if (char == null) {
          throw SyntaxError(
            'invalid character escape',
            spanFrom(-1),
          );
        }
        buffer.write(char);
      } else {
        buffer.write(eatWhile(
            (char) => char != quote && char != dollar && char != backslash));
      }
    } while (!_eos && current != quote && current != dollar);

    if (buffer.isEmpty) {
      return null;
    }

    return PlainText(buffer.toString(), spanFrom(start));
  }

  Iterable<Token>? _templateExpr() {
    if (current != dollar) return null;

    final dollarTok = Char(currentChar, spanFrom(offset++));

    if (currentChar == '{') {
      final braceTok = Char(currentChar, spanFrom(offset++));
      final tokens = tokenize()
          .takeWhile((_) => !_eos && currentChar != '}')
          .toList(growable: false);

      return [
        dollarTok,
        braceTok,
        ...tokens,
        if (!_eos && currentChar == '}') Char(currentChar, spanFrom(offset++))
      ];
    } else {
      final ident = identifier();
      return [dollarTok, if (ident != null) ident];
    }
  }

  Iterable<Token> _string() sync* {
    final quote = currentChar;
    final quoteCode = current;

    yield Char(quote, spanFrom(offset++));

    while (!_eos && current != quoteCode) {
      final token = _plaintext(quoteCode) ?? _templateExpr();
      if (token == null) {
        throw SyntaxError(
          'unrecognized token',
          source.span(offset, offset),
        );
      } else if (token is Token) {
        yield token;
      } else {
        for (final tok in token as Iterable<Token>) {
          yield tok;
        }
      }
    }

    if (!_eos) {
      yield Char(currentChar, spanFrom(offset));
      offset++;
    }
  }

  Iterable<Token>? string() =>
      switch (currentChar) { '"' || "'" => _string(), _ => null };

  void _trimSpace() {
    offset += count((char) => _spaces.contains(char));
  }

  Iterable<Token> tokenize() sync* {
    while (!done) {
      _trimSpace();

      if (done) return;
      if (_eos) {
        offset++;
        yield Eos(source.span(source.length - 1, source.length - 1));
        return;
      }

      final token = newline() ??
          comment() ??
          multiChar() ??
          char() ??
          identifier() ??
          number();

      if (token != null) {
        yield token;
      } else {
        final str = string();
        if (str == null) {
          throw SyntaxError(
            'unrecognized token',
            source.span(offset, offset),
          );
        }

        for (final tok in str) {
          yield tok;
        }
      }
    }
  }
}
