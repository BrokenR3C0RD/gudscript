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

import 'package:source_span/source_span.dart';

extension on String {
  String indent() => split('\n')
      .indexed
      .map((t) => t.$1 == 0 ? t.$2 : '    ${t.$2}')
      .join('\n');
}

abstract class Node {
  FileSpan span;

  Node(this.span);

  @override
  String toString() => '$runtimeType[${span.start.toolString}]';
}

abstract class Stmt extends Node {
  Stmt(super.span);
}

abstract class Expr extends Stmt {
  Expr(super.span);
}

enum BlockType {
  normal,
  loop,
  when,
  function,
}

class Block extends Stmt {
  final BlockType type;
  final List<Stmt> statements;

  Block(super.span, this.type, this.statements);
}

abstract class UnaryExpr extends Expr {
  final Expr expression;
  UnaryExpr(super.span, {required this.expression});

  @override
  String toString() => '${super.toString()}:\n'
      '    ${expression.toString().indent()}';
}

abstract class BinaryExpr extends Expr {
  final Expr left;
  final Expr right;

  BinaryExpr(super.span, {required this.left, required this.right});
  @override
  String toString() => '${super.toString()}:\n'
      '    Left: ${left.toString().indent()}\n'
      '    Right: ${right.toString().indent()}';
}

mixin Assignable on Expr {}

final class Variable extends Expr with Assignable {
  final String name;

  Variable(super.span, this.name);

  @override
  String toString() => '${super.toString()} = $name';
}

final class Number extends Expr {
  final num value;

  Number(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class Boolean extends Expr {
  final bool value;

  Boolean(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class MemberAccess extends Expr with Assignable {
  final Expr parent;
  final Expr property;

  MemberAccess(super.span, {required this.parent, required this.property});

  @override
  String toString() => '${super.toString()}:\n'
      '    Parent: ${parent.toString().indent()}\n'
      '    Property: ${property.toString().indent()}';
}

final class FunctionCall extends Expr {
  final Expr callee;
  final List<Expr> parameters;

  FunctionCall(super.span, {required this.callee, required this.parameters});

  @override
  String toString() => '${super.toString()}: $callee (\n'
      '  ${parameters.join(',\n').indent()}\n'
      ')';
}

final class PostfixIncrement extends Expr {
  final Assignable target;

  PostfixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PostfixDecrement extends Expr {
  final Assignable target;

  PostfixDecrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixIncrement extends Expr {
  final Assignable target;

  PrefixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixDecrement extends Expr {
  final Assignable target;

  PrefixDecrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class Not extends UnaryExpr {
  Not(super.span, {required super.expression});
}

final class Negate extends UnaryExpr {
  Negate(super.span, {required super.expression});
}

final class Exponentiate extends BinaryExpr {
  Exponentiate(super.span, {required super.left, required super.right});
}

final class Multiply extends BinaryExpr {
  Multiply(super.span, {required super.left, required super.right});
}

final class Divide extends BinaryExpr {
  Divide(super.span, {required super.left, required super.right});
}

final class Modulo extends BinaryExpr {
  Modulo(super.span, {required super.left, required super.right});
}

final class Add extends BinaryExpr {
  Add(super.span, {required super.left, required super.right});
}

final class Subtract extends BinaryExpr {
  Subtract(super.span, {required super.left, required super.right});
}

final class LeftShift extends BinaryExpr {
  LeftShift(super.span, {required super.left, required super.right});
}

final class RightShift extends BinaryExpr {
  RightShift(super.span, {required super.left, required super.right});
}

final class LesserEqual extends BinaryExpr {
  LesserEqual(super.span, {required super.left, required super.right});
}

final class GreaterEqual extends BinaryExpr {
  GreaterEqual(super.span, {required super.left, required super.right});
}

final class Lesser extends BinaryExpr {
  Lesser(super.span, {required super.left, required super.right});
}

final class Greater extends BinaryExpr {
  Greater(super.span, {required super.left, required super.right});
}

final class Equal extends BinaryExpr {
  Equal(super.span, {required super.left, required super.right});
}

final class NotEqual extends BinaryExpr {
  NotEqual(super.span, {required super.left, required super.right});
}

final class BitAnd extends BinaryExpr {
  BitAnd(super.span, {required super.left, required super.right});
}

final class BitOr extends BinaryExpr {
  BitOr(super.span, {required super.left, required super.right});
}

final class BitXor extends BinaryExpr {
  BitXor(super.span, {required super.left, required super.right});
}

final class LogicalAnd extends BinaryExpr {
  LogicalAnd(super.span, {required super.left, required super.right});
}

final class LogicalOr extends BinaryExpr {
  LogicalOr(super.span, {required super.left, required super.right});
}

final class Ternary extends Expr {
  final Expr condition;
  final Expr ifTrue;
  final Expr ifFalse;

  Ternary(super.span,
      {required this.condition, required this.ifTrue, required this.ifFalse});

  @override
  String toString() => '${super.toString()}:\n'
      '  Condition: ${condition.toString().indent()}\n'
      '  If `true`: ${ifTrue.toString().indent()}\n'
      '  If `false`: ${ifFalse.toString().indent()})';
}

final class VariableDefine extends Stmt {
  final Variable target;
  final Expr? value;

  VariableDefine(super.span, {required this.target, this.value});

  @override
  String toString() => '${super.toString()}:\n'
      '  Variable: ${target.toString().indent()}\n'
      '  Value: ${value.toString().indent()}';
}

final class Assign extends Stmt {
  final Assignable target;
  final Expr value;

  Assign(super.span, {required this.target, required this.value});
}
