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

abstract class Token<V> {
  final V value;

  Token(this.value);

  String get prettyValue {
    if (value is String) {
      return "'${_toReadableString(value as String)}'";
    } else if (value is List) {
      return '[${(value as List).join(', ')}]';
    } else {
      return value.toString();
    }
  }

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
  String toString() => '$runtimeType: $prettyValue';
}

class SpannedToken<T extends Token> {
  final T token;
  final FileSpan span;

  SpannedToken(this.span, this.token);

  @override
  String toString() =>
      '${token.runtimeType}[${span.start.toolString}]: ${token.prettyValue}';

  @override
  bool operator ==(Object other) {
    if (other is T) {
      return token == other;
    } else if (other is SpannedToken) {
      return token.hashCode == other.hashCode;
    } else {
      return false;
    }
  }

  SpannedToken<U>? tryCast<U extends Token>() {
    if (token is! U) {
      return null;
    }

    return SpannedToken(span, token as U);
  }

  @override
  int get hashCode => Object.hash(span.hashCode, token.hashCode);
}

class Eos extends Token<void> {
  Eos() : super(null);
}

class Newline extends Token<String> {
  static const valid = {
    '\r', // CR
    '\n', // LF
    '\u2028', // LS
    '\u2029' // PS
  };
  Newline(super.value);
}

class Identifier extends Token<String> {
  Identifier(super.value);
}

class NumberLiteral extends Token<num> {
  NumberLiteral(super.value);
}

class Comment extends Token<String> {
  Comment(super.value);
}

class PlainText extends Token<String> {
  PlainText(super.value);
}

class Char extends Token<String> {
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
    '~',
  };

  Char(super.value);
}

class MultiChar extends Token<String> {
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

  MultiChar(super.value);
}

class Keyword extends Token<String> {
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
  Keyword(super.value);
}
