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
import 'package:gudscript/src/lexer.dart';
import 'package:gudscript/src/nodes.dart';
import 'package:gudscript/src/tokens.dart';

typedef SwitchEat<T extends Token, N> = Map<String, N Function(T)>;
typedef SwitchFold<T extends Token, E> = Map<String, E Function(T, E)>;

class Parser {
  final List<Token> tokens;
  int offset = 0;

  Parser(this.tokens);
  Parser.fromString(String source, {Object? url})
      : tokens = Lexer.fromString(source, url: url).tokenize().toList();

  Token? peek() {
    final tok = tokens.elementAtOrNull(offset);
    return tok;
  }

  T? eat<T extends Token>() {
    final peek = this.peek();

    if (peek is! T) return null;

    offset++;
    return peek;
  }

  T? eatIfValue<T extends Token>(String value) {
    final peek = this.peek();
    if (peek is! T || peek.value != value) return null;

    offset++;
    return peek;
  }

  T? eatIf<T extends Token>(bool Function(T)? test) {
    final peek = this.peek();

    if (peek is! T) return null;
    if (test != null && !test(peek)) {
      return null;
    }

    offset++;
    return peek;
  }

  N? eatSwitch<T extends Token, N extends Node>(SwitchEat<T, N> switches) {
    final peek = this.peek();
    if (peek is! T) return null;

    final match = switches[peek.value];
    if (match == null) return null;

    offset++;
    return match(peek);
  }

  N? switchFold<T extends Token, N extends Node>(
      N? initialValue, SwitchFold<T, N> cases) {
    if (initialValue == null) return null;
    var acc = initialValue;

    while (true) {
      final peek = this.peek();
      if (peek is! T) return acc;

      final match = cases[peek.value];
      if (match == null) return acc;
      offset += 1;

      acc = match(peek, acc);
    }
  }

  N? fold<N>(N? initialValue, N? Function(N) accumulate) {
    if (initialValue == null) return null;
    var acc = initialValue;

    while (true) {
      final res = accumulate(acc);
      if (res == null) return acc;
      acc = res;
    }
  }

  Keyword? keyword(String name) => eatIfValue(name);
  Char? char(String char) => eatIfValue(char);

  Char expectChar(String char) => expect(this.char(char), 'expected `$char`');

  V expect<V>(V? value, [String? message]) {
    if (value == null) {
      final peek = this.peek();
      if (peek == null) {
        throw StateError('past end-of-source');
      }

      throw SyntaxError(
          message != null
              ? 'expected $message, found ${peek.readableName}'
              : 'unexpected ${peek.readableName}',
          peek.span);
    }

    return value;
  }

  MultiChar? multichar(String multichar) => eatIfValue(multichar);
  Keyword? $break() => keyword('break');
  Keyword? $case() => keyword('case');
  Keyword? $continue() => keyword('continue');
  Keyword? $default() => keyword('default');
  Keyword? $do() => keyword('do');
  Keyword? $else() => keyword('else');
  Keyword? $false() => keyword('false');
  Keyword? $for() => keyword('for');
  Keyword? $if() => keyword('if');
  Keyword? $in() => keyword('in');
  Keyword? $null() => keyword('null');
  Keyword? $on() => keyword('on');
  Keyword? $return() => keyword('return');
  Keyword? $switch() => keyword('switch');
  Keyword? $true() => keyword('true');
  Keyword? $var() => keyword('var');
  Keyword? $when() => keyword('when');
  Keyword? $while() => keyword('while');

  Number? number() {
    final token = eat<NumberLiteral>();
    if (token == null) return null;

    final num value;
    try {
      value = switch (token.type) {
        NumberLiteralType.decimal => double.parse(token.value),
        NumberLiteralType(radix: final radix) =>
          int.parse(token.value, radix: radix),
      };
    } on FormatException catch (e) {
      throw SyntaxError('invalid ${token.type.name} literal', token.span,
          primaryLabel: e.message);
    }

    return Number(token.span, value);
  }

  Boolean? boolean() => switch ($true() ?? $false()) {
        Keyword(value: 'true', span: final span) => Boolean(span, true),
        Keyword(value: 'false', span: final span) => Boolean(span, false),
        _ => null
      };

  Variable? variable() => switch (eat<Identifier>()) {
        Identifier(value: final value, span: final span) =>
          Variable(span, value),
        _ => null
      };

  Expr? grouping() {
    final open = char('(');
    if (open == null) return null;

    final expr = expect(expression(), 'expression');
    final close = expectChar(')');

    final span = open.span.expand(close.span);
    return expr..span = span;
  }

  Expr? primitive() => number() ?? variable() ?? boolean() ?? grouping();

  Expr? accessCall() => switchFold<Char, Expr>(primitive(), {
        '.': (op, left) {
          final property = expect(variable());
          final span = left.span.expand(property.span);
          return MemberAccess(span, parent: left, property: property);
        },
        '[': (op, left) {
          final property = expect(expression());
          final close = expectChar(']');
          final span = left.span.expand(close.span);
          return MemberAccess(span, parent: left, property: property);
        },
        '(': (op, left) {
          final parameters = <Expr>[];
          var span = left.span;

          while (true) {
            final expr = expect(char(')') ?? expression(), 'expression, `)`');
            if (expr is Char) {
              span = span.expand(expr.span);
              break;
            } else {
              parameters.add(expr as Expr);
              final next = expect(char(',') ?? char(')'), '`,`, `)`');
              if (next.value == ')') {
                span = span.expand(expr.span);
                break;
              }
            }
          }

          return FunctionCall(span, callee: left, parameters: parameters);
        }
      });

  Expr? postfix() => switchFold<MultiChar, Expr>(accessCall(), {
        '++': (operator, left) {
          if (left is! Assignable) {
            throw SyntaxError(
                'left-hand side must be assignable', operator.span,
                primaryLabel: 'this implicitly assigns',
                secondarySpans: {
                  left.span: '... but this cannot be assigned to',
                });
          }

          final span = left.span.expand(operator.span);
          return PostfixIncrement(span, left);
        },
        '--': (operator, left) {
          if (left is! Assignable) {
            throw SyntaxError(
                'left-hand side must be assignable', operator.span,
                primaryLabel: 'this implicitly assigns',
                secondarySpans: {
                  left.span: '... but this cannot be assigned to',
                });
          }
          final span = left.span.expand(operator.span);
          return PostfixDecrement(span, left);
        }
      });

  Expr? prefix() =>
      eatSwitch<Char, Expr>({
        '!': (operator) {
          final right = expect(prefix(), 'expression');
          final span = operator.span.expand(right.span);
          return Not(span, expression: right);
        },
        '-': (operator) {
          final right = expect(prefix(), 'expression');
          final span = operator.span.expand(right.span);
          return Negate(span, expression: right);
        }
      }) ??
      eatSwitch<MultiChar, Expr>({
        '++': (operator) {
          final right = expect(prefix(), 'expression');
          if (right is! Assignable) {
            throw SyntaxError(
                'right-hand side must be assignable', operator.span,
                primaryLabel: 'this implicitly assigns',
                secondarySpans: {
                  right.span: '... but this cannot be assigned to',
                });
          }
          final span = operator.span.expand(right.span);
          return PrefixIncrement(span, right);
        },
        '--': (operator) {
          final right = expect(prefix(), 'expression');
          if (right is! Assignable) {
            throw SyntaxError(
                'right-hand side must be assignable', operator.span,
                primaryLabel: 'this implicitly assigns',
                secondarySpans: {
                  right.span: '... but this cannot be assigned to',
                });
          }
          final span = operator.span.expand(right.span);
          return PrefixDecrement(span, right);
        }
      }) ??
      postfix();

  Expr? exponentiation() => fold(prefix(), (left) {
        final operator = multichar('**');
        if (operator == null) return null;
        final right = expect(exponentiation(), 'expression');
        final span = left.span.expand(right.span);
        return Exponentiate(span, left: left, right: right);
      });

  Expr? multiplicative() => switchFold<Char, Expr>(exponentiation(), {
        '*': (operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Multiply(span, left: left, right: right);
        },
        '/': (operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Divide(span, left: left, right: right);
        },
        '%': (operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Modulo(span, left: left, right: right);
        }
      });

  Expr? additive() => switchFold<Char, Expr>(multiplicative(), {
        '+': (Char operator, left) {
          final right = expect(multiplicative(), 'expression');
          final span = left.span.expand(right.span);
          return Add(span, left: left, right: right);
        },
        '-': (Char operator, left) {
          final right = expect(multiplicative(), 'expression');
          final span = left.span.expand(right.span);
          return Subtract(span, left: left, right: right);
        }
      });

  Expr? bitwiseShift() => switchFold<MultiChar, Expr>(additive(), {
        '<<': (operator, left) {
          final right = expect(additive(), 'expression');
          final span = left.span.expand(right.span);
          return LeftShift(span, left: left, right: right);
        },
        '>>': (operator, left) {
          final right = expect(additive(), 'expression');
          final span = left.span.expand(right.span);
          return RightShift(span, left: left, right: right);
        }
      });

  Expr? relational() => fold(
      bitwiseShift(),
      (left) =>
          eatSwitch<MultiChar, Expr>({
            '<=': (operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return LesserEqual(span, left: left, right: right);
            },
            '>=': (operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return GreaterEqual(span, left: left, right: right);
            }
          }) ??
          eatSwitch<Char, Expr>({
            '<': (operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return Lesser(span, left: left, right: right);
            },
            '>': (operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return Greater(span, left: left, right: right);
            }
          }));

  Expr? equality() => switchFold<MultiChar, Expr>(relational(), {
        '==': (operator, left) {
          final right = expect(relational(), 'expression');
          final span = left.span.expand(right.span);
          return Equal(span, left: left, right: right);
        },
        '!=': (operator, left) {
          final right = expect(relational(), 'expression');
          final span = left.span.expand(right.span);
          return NotEqual(span, left: left, right: right);
        }
      });

  Expr? bitwiseAnd() => fold(equality(), (left) {
        final operator = char('&');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitAnd(span, left: left, right: right);
      });

  Expr? bitwiseOr() => fold(bitwiseAnd(), (left) {
        final operator = char('|');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitOr(span, left: left, right: right);
      });

  Expr? bitwiseXor() => fold(bitwiseOr(), (left) {
        final operator = char('^');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expr? logicalAnd() => fold(bitwiseXor(), (left) {
        final operator = multichar('&&');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expr? logicalOr() => fold(logicalAnd(), (left) {
        final operator = multichar('||');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expr? ternary() => fold(logicalOr(), (left) {
        final operator = char('?');
        if (operator == null) return null;

        final ifTrue = expect(expression(), 'expression');
        expectChar(':');
        final ifFalse = expect(ternary(), 'expression');
        final span = left.span.expand(ifFalse.span);
        return Ternary(span, condition: left, ifTrue: ifTrue, ifFalse: ifFalse);
      });

  Stmt? assignment() {
    final target = expression();
    if (target == null) return null;

    if (target is! Assignable) {
      return target;
    }

    final op = char('=');
    if (op == null) return null;

    final value = expect(expression(), 'expression');
    final span = target.span.expand(value.span);
    return Assign(span, target: target, value: value);
  }

  Stmt? declare() {
    final key = $var();
    if (key == null) return null;

    final target = expect(variable(), 'identifier');

    Expr? value;
    if (char('=') != null) {
      value = expect(expression(), 'expression');
    }

    final span = key.span.expand((value ?? target).span);
    return VariableDefine(span, target: target, value: value);
  }

  Stmt? statement() => declare() ?? assignment() ?? expression();

  Expr? expression() => ternary();
}
