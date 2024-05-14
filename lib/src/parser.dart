import 'package:gudscript/src/lexer.dart';
import 'package:gudscript/src/nodes.dart';
import 'package:gudscript/src/tokens.dart';
import 'package:source_span/source_span.dart';

class GrammarException implements Exception {
  final FileSpan span;
  final String message;

  GrammarException(this.message, this.span);

  @override
  String toString() =>
      'GrammarException:\nerror: $message\n --> ${span.start.toolString}\n${span.highlight()}';
}

typedef SwitchEat<T extends Token<V>, V, N>
    = Map<V, N Function(SpannedToken<T>)>;

typedef SwitchFold<T extends Token<V>, V, E>
    = Map<V, E Function(SpannedToken<T>, E)>;

class Parser {
  final List<SpannedToken> tokens;
  int offset = 0;

  Parser(this.tokens);
  Parser.fromString(String source, {Object? url})
      : tokens = Lexer.fromString(source, url: url).tokenize().toList();

  SpannedToken? peek() {
    final tok = tokens.elementAtOrNull(offset);
    return tok;
  }

  SpannedToken<T>? eat<T extends Token>() {
    final peek = this.peek()?.tryCast<T>();

    if (peek == null) return null;

    offset++;
    return peek;
  }

  SpannedToken<T>? eatIfValue<T extends Token<V>, V>(V value) {
    final peek = this.peek()?.tryCast<T>();
    if (peek == null || peek.token.value != value) return null;

    offset++;
    return peek;
  }

  SpannedToken<T>? eatIf<T extends Token>(bool Function(T)? test) {
    final peek = this.peek()?.tryCast<T>();

    if (peek == null) return null;
    if (test != null && !test(peek.token)) {
      return null;
    }

    offset++;
    return SpannedToken(peek.span, peek.token);
  }

  N? eatSwitch<T extends Token<V>, V, N>(SwitchEat<T, V, N> switches) {
    final tok = peek()?.tryCast<T>();
    if (tok == null) return null;

    final match = switches[tok.token.value];
    if (match == null) return null;

    offset++;
    return match(SpannedToken(tok.span, tok.token));
  }

  E? switchFold<E extends Object, T extends Token<V>, V>(
      E? initialValue, SwitchFold<T, V, E> cases) {
    if (initialValue == null) return null;
    var acc = initialValue;

    while (true) {
      final peek = this.peek()?.tryCast<T>();
      if (peek == null) return acc;

      final match = cases[peek.token.value];
      if (match == null) return acc;
      offset += 1;

      acc = match(peek, acc);
    }
  }

  E? fold<E>(E? initialValue, E? Function(E) accumulate) {
    if (initialValue == null) return null;
    var acc = initialValue;

    while (true) {
      final res = accumulate(acc);
      if (res == null) return acc;
      acc = res;
    }
  }

  SpannedToken<Keyword>? keyword(String name) => eatIfValue(name);
  SpannedToken<Char>? char(String char) => eatIfValue(char);

  SpannedToken<Char> expectChar(String char) =>
      expect(this.char(char), 'expected `$char`');

  V expect<V>(V? value, [String message = 'unexpected token']) {
    if (value == null) {
      final peek = this.peek();
      if (peek == null) {
        throw StateError('parser error: expect() ran past end-of-source');
      }
      throw GrammarException(message, peek.span);
    }

    return value;
  }

  SpannedToken<MultiChar>? multichar(String multichar) => eatIfValue(multichar);
  SpannedToken<Keyword>? $break() => keyword('break');
  SpannedToken<Keyword>? $case() => keyword('case');
  SpannedToken<Keyword>? $continue() => keyword('continue');
  SpannedToken<Keyword>? $default() => keyword('default');
  SpannedToken<Keyword>? $do() => keyword('do');
  SpannedToken<Keyword>? $else() => keyword('else');
  SpannedToken<Keyword>? $false() => keyword('false');
  SpannedToken<Keyword>? $for() => keyword('for');
  SpannedToken<Keyword>? $if() => keyword('if');
  SpannedToken<Keyword>? $in() => keyword('in');
  SpannedToken<Keyword>? $null() => keyword('null');
  SpannedToken<Keyword>? $on() => keyword('on');
  SpannedToken<Keyword>? $return() => keyword('return');
  SpannedToken<Keyword>? $switch() => keyword('switch');
  SpannedToken<Keyword>? $true() => keyword('true');
  SpannedToken<Keyword>? $var() => keyword('var');
  SpannedToken<Keyword>? $when() => keyword('when');
  SpannedToken<Keyword>? $while() => keyword('while');

  Expression? grouping() {
    final open = char('(');
    if (open == null) return null;

    final expr = expect(expression(), 'expected expression');
    final close = expectChar(')');

    final span = open.span.expand(close.span);
    return expr..span = span;
  }

  Number? number() => switch (eat<NumberLiteral>()) {
        SpannedToken(
          span: final span,
          token: NumberLiteral(value: final value)
        ) =>
          Number(span, value),
        _ => null
      };

  Boolean? boolean() => switch ($true() ?? $false()) {
        SpannedToken(span: final span, token: Keyword(value: 'true')) =>
          Boolean(span, true),
        SpannedToken(span: final span, token: Keyword(value: 'false')) =>
          Boolean(span, false),
        _ => null
      };

  Variable? variable() => switch (eat<Identifier>()) {
        SpannedToken(span: final span, token: Identifier(value: final value)) =>
          Variable(span, value),
        _ => null
      };

  Expression? primitive() => number() ?? variable() ?? boolean() ?? grouping();

  Expression? accessCall() => switchFold(primitive(), {
        '.': (SpannedToken<Char> op, left) {
          final property = expect(variable());
          final span = left.span.expand(property.span);
          return MemberAccess(span, parent: left, property: property);
        },
        '[': (SpannedToken<Char> op, left) {
          final property = expect(expression());
          final close = expectChar(']');
          final span = left.span.expand(close.span);
          return MemberAccess(span, parent: left, property: property);
        },
        '(': (SpannedToken<Char> op, left) {
          final parameters = <Expression>[];
          var span = left.span;

          while (true) {
            final expr = expect(char(')') ?? expression(), 'expected `)`');
            if (expr is SpannedToken) {
              span = span.expand(expr.span);
              break;
            } else {
              parameters.add(expr as Expression);
              final next = expect(char(',') ?? char(')'), '`,` or `)`');
              if (next.token.value == ')') {
                span = span.expand(expr.span);
                break;
              }
            }
          }

          return FunctionCall(span, callee: left, parameters: parameters);
        }
      });

  Expression? postfix() => switchFold(accessCall(), {
        '++': (SpannedToken<MultiChar> operator, left) {
          if (left is! AssignTarget) {
            throw GrammarException(
                'left-hand side must be assignable', left.span);
          }

          final span = left.span.expand(operator.span);
          return PostfixIncrement(span, left);
        },
        '--': (SpannedToken<MultiChar> operator, left) {
          if (left is! AssignTarget) {
            throw GrammarException(
                'left-hand side must be assignable', left.span);
          }
          final span = left.span.expand(operator.span);
          return PostfixDecrement(span, left);
        }
      });

  Expression? prefix() =>
      eatSwitch({
        '!': (SpannedToken<Char> operator) {
          final right = expect(prefix(), 'expression');
          final span = operator.span.expand(right.span);
          return Not(span, expression: right);
        },
        '-': (SpannedToken<Char> operator) {
          final right = expect(prefix(), 'expression');
          final span = operator.span.expand(right.span);
          return Negate(span, expression: right);
        }
      }) ??
      eatSwitch({
        '++': (SpannedToken<MultiChar> operator) {
          final right = expect(prefix(), 'expression');
          if (right is! AssignTarget) {
            throw GrammarException(
                'right-hand side must be assignable', right.span);
          }
          final span = operator.span.expand(right.span);
          return PrefixIncrement(span, right);
        },
        '--': (SpannedToken<MultiChar> operator) {
          final right = expect(prefix(), 'expression');
          if (right is! AssignTarget) {
            throw GrammarException(
                'right-hand side must be assignable', right.span);
          }
          final span = operator.span.expand(right.span);
          return PrefixDecrement(span, right);
        }
      }) ??
      postfix();

  Expression? exponentiation() => fold(prefix(), (left) {
        final operator = multichar('**');
        if (operator == null) return null;
        final right = expect(exponentiation(), 'expression');
        final span = left.span.expand(right.span);
        return Exponentiate(span, left: left, right: right);
      });

  Expression? multiplicative() => switchFold(exponentiation(), {
        '*': (SpannedToken<Char> operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Multiply(span, left: left, right: right);
        },
        '/': (SpannedToken<Char> operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Divide(span, left: left, right: right);
        },
        '%': (SpannedToken<Char> operator, left) {
          final right = expect(exponentiation(), 'expression');
          final span = left.span.expand(right.span);
          return Modulo(span, left: left, right: right);
        }
      });

  Expression? additive() => switchFold(multiplicative(), {
        '+': (SpannedToken<Char> operator, left) {
          final right = expect(multiplicative(), 'expression');
          final span = left.span.expand(right.span);
          return Add(span, left: left, right: right);
        },
        '-': (SpannedToken<Char> operator, left) {
          final right = expect(multiplicative(), 'expression');
          final span = left.span.expand(right.span);
          return Subtract(span, left: left, right: right);
        }
      });

  Expression? bitwiseShift() => switchFold(additive(), {
        '<<': (SpannedToken<MultiChar> operator, left) {
          final right = expect(additive(), 'expression');
          final span = left.span.expand(right.span);
          return LeftShift(span, left: left, right: right);
        },
        '>>': (SpannedToken<MultiChar> operator, left) {
          final right = expect(additive(), 'expression');
          final span = left.span.expand(right.span);
          return RightShift(span, left: left, right: right);
        }
      });

  Expression? relational() => fold(
      bitwiseShift(),
      (left) =>
          eatSwitch({
            '<=': (SpannedToken<MultiChar> operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return LesserEqual(span, left: left, right: right);
            },
            '>=': (SpannedToken<MultiChar> operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return GreaterEqual(span, left: left, right: right);
            }
          }) ??
          eatSwitch({
            '<': (SpannedToken<Char> operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return Lesser(span, left: left, right: right);
            },
            '>': (SpannedToken<Char> operator) {
              final right = expect(bitwiseShift(), 'expression');
              final span = left.span.expand(right.span);
              return Greater(span, left: left, right: right);
            }
          }));

  Expression? equality() => switchFold(relational(), {
        '==': (SpannedToken<MultiChar> operator, left) {
          final right = expect(relational(), 'expression');
          final span = left.span.expand(right.span);
          return Equal(span, left: left, right: right);
        },
        '!=': (SpannedToken<MultiChar> operator, left) {
          final right = expect(relational(), 'expression');
          final span = left.span.expand(right.span);
          return NotEqual(span, left: left, right: right);
        }
      });

  Expression? bitwiseAnd() => fold(equality(), (left) {
        final operator = char('&');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitAnd(span, left: left, right: right);
      });

  Expression? bitwiseOr() => fold(bitwiseAnd(), (left) {
        final operator = char('|');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitOr(span, left: left, right: right);
      });

  Expression? bitwiseXor() => fold(bitwiseOr(), (left) {
        final operator = char('^');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expression? logicalAnd() => fold(bitwiseXor(), (left) {
        final operator = multichar('&&');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expression? logicalOr() => fold(logicalAnd(), (left) {
        final operator = multichar('||');
        if (operator == null) return null;
        final right = expect(equality(), 'expression');
        final span = left.span.expand(right.span);
        return BitXor(span, left: left, right: right);
      });

  Expression? ternary() => fold(logicalOr(), (left) {
        final operator = char('?');
        if (operator == null) return null;

        final ifTrue = expect(expression(), 'expression');
        expectChar(':');
        final ifFalse = expect(ternary(), 'expression');
        final span = left.span.expand(ifFalse.span);
        return Ternary(span, condition: left, ifTrue: ifTrue, ifFalse: ifFalse);
      });

  Statement? assignment() {
    final target = expression();
    if (target == null) return null;

    if (target is! AssignTarget) {
      return target;
    }

    final op = char('=');
    if (op == null) return null;

    final value = expect(expression(), 'expression');
    final span = target.span.expand(value.span);
    return Assign(span, target: target, value: value);
  }

  Statement? declare() {
    final key = $var();
    if (key == null) return null;

    final target = expect(variable(), 'variable name');

    Expression? value;
    if (char('=') != null) {
      value = expect(expression(), 'expression');
    }

    final span = key.span.expand((value ?? target).span);
    return VariableDefine(span, target: target, value: value);
  }

  Statement? statement() => declare() ?? assignment() ?? expression();

  Expression? expression() => ternary();
}
