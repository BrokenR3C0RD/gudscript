import 'package:source_span/source_span.dart';

// Modified from PetitParser
// https://github.com/petitparser/dart-petitparser/blob/16e7d2c7971727b0ad749d834b4c7e800f761040/lib/src/parser/character/code.dart
/// Converts a character to a readable string.
String _toReadableString(String element) =>
    element.runes.map(_toFormattedChar).join();

String _toFormattedChar(int code) {
  switch (code) {
    case 0x00:
      return r'\0'; // null character
    case 0x08:
      return r'\b'; // backspace
    case 0x09:
      return r'\t'; // horizontal tab
    case 0x0A:
      return r'\n'; // new line
    case 0x0B:
      return r'\v'; // vertical tab
    case 0x0C:
      return r'\f'; // form feed
    case 0x0D:
      return r'\r'; // carriage return
    case 0x22:
      return r'"'; // double quote
    case 0x27:
      return r"'"; // single quote
    case 0x5C:
      return r'\\'; // backslash
  }
  if (code < 0x20 || code == 0x7F) {
    return '\\x${code.toRadixString(16).padLeft(2, '0')}';
  }
  if (code >= 0x7F) {
    return '\\u${code.toRadixString(16).padLeft(2, '0')}';
  }
  return String.fromCharCode(code);
}

abstract class Token {
  final String value;
  final FileSpan span;

  Token(this.value, this.span);

  String get readableName => '`${_toReadableString(value)}`';

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType == runtimeType) {
      return hashCode == other.hashCode;
    } else {
      return false;
    }
  }

  @override
  String toString() =>
      '$runtimeType[${span.start.toolString}]: ${_toReadableString(value)}';
}

class Eos extends Token {
  Eos(FileSpan span) : super('', span);

  @override
  String get readableName => 'end of source';
}

class Newline extends Token {
  static const valid = {
    '\r', // CR
    '\n', // LF
    '\u2028', // LS
    '\u2029' // PS
  };

  @override
  String get readableName => 'newline';

  Newline(super.value, super.span);
}

class Identifier extends Token {
  Identifier(super.value, super.span);

  @override
  String get readableName => 'identifier';
}

enum NumberLiteralType {
  integer(10, 'integer'),
  decimal(10, 'floating-point'),
  binary(2, 'binary'),
  hex(16, 'hex');

  final int radix;
  final String name;
  const NumberLiteralType(this.radix, this.name);
}

class NumberLiteral extends Token {
  final NumberLiteralType type;
  NumberLiteral(super.value, super.span, this.type);

  @override
  String get readableName => '${type.name} literal';
}

class Comment extends Token {
  Comment(super.value, super.span);
}

class PlainText extends Token {
  PlainText(super.value, super.span);

  @override
  String get readableName => 'string text';
}

class Char extends Token {
  static const valid = {
    '!',
    '%',
    '&',
    '(',
    ')',
    '*',
    '+',
    ',',
    '-',
    '.',
    '/',
    ':',
    ';',
    '<',
    '=',
    '>',
    '?',
    '^',
    '{',
    '|',
    '}',
    '[',
    ']'
  };

  Char(super.value, super.span);
}

class MultiChar extends Token {
  static const valid = {
    '&&',
    '**',
    '++',
    '--',
    '..',
    '<<',
    '==',
    '>>',
    '!=',
    '>=',
    '<=',
    '||',
  };

  MultiChar(super.value, super.span);
}

class Keyword extends Token {
  static const keywords = {
    'break',
    'case',
    'continue',
    'default',
    'do',
    'else',
    'false',
    'for',
    'if',
    'in',
    'null',
    'on',
    'return',
    'switch',
    'true',
    'var',
    'when',
    'while',
  };
  Keyword(super.value, super.span);
}
