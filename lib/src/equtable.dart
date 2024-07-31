import 'package:collection/collection.dart';
import 'package:data_class/src/extensions/buider_extension.dart';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';

final dartCore = Uri.parse('dart:core');
final dataClassMacro = Uri.parse(
    'package:data_class/src/deep_equals/deep_equels.dart');

macro class Equatable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const Equatable();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder,) {
    return [
      _declareEquals(clazz, builder),
      _declareHashCode(clazz, builder),
    ].wait;
  }

  @override
  Future<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder builder,) {
    return [
      _buildEquals(clazz, builder),
      // _buildHashCode(clazz, builder),
    ].wait;
  }

  Future<void> _declareEquals(ClassDeclaration clazz,
      MemberDeclarationBuilder builder,) async {
    final (object, boolean) = await (
    builder.codeFrom(dartCore, 'Object'),
    builder.codeFrom(dartCore, 'bool'),
    ).wait;
    return builder.declareInType(
      DeclarationCode.fromParts(
        ['external ', boolean, ' operator ==(', object, ' other);\n'].indent(),
      ),
    );
  }

  Future<void> _declareHashCode(ClassDeclaration clazz,
      MemberDeclarationBuilder builder,) async {
    final integer = await builder.codeFrom(dartCore, 'int');
    return builder.declareInType(
      DeclarationCode.fromParts(
          ['external ', integer, ' get hashCode;\n'].indent()),
    );
  }

  Future<void> _buildEquals(ClassDeclaration clazz,
      TypeDefinitionBuilder builder,) async {
    final methods = await builder.methodsOf(clazz);
    final equality = methods.firstWhereOrNull(
          (m) => m.identifier.name == '==',
    );
    if (equality == null) return;

    final (equalsMethod, deepEquals, identical, fields) = await (
    builder.buildMethod(equality.identifier),
    builder.codeFrom(dataClassMacro, 'deepEquals'),
    builder.codeFrom(dartCore, 'identical'),
    builder.allFieldsOf(clazz),
    ).wait;

    if (fields.isEmpty) {
      return equalsMethod.augment(
        FunctionBodyCode.fromParts(
          [
            '{\n',
            ...[ 'if (', identical, ' (this, other)', ')', 'return true;\n',
              'return other is ${clazz.identifier.name} &&\n',
              'other.runtimeType == runtimeType;\n',
            ].indent(4),
            '}\n',
          ],
        ),
      );
    }

    final fieldNames = fields.map((f) => f.identifier.name);
    final lastField = fieldNames.last;
    return equalsMethod.augment(
      FunctionBodyCode.fromParts(
        [
          '{\n',
          ...[ 'if (', identical, ' (this, other)', ')', ' return true;\n',
            'return other is ${clazz.identifier.name} && \n',
            'other.runtimeType == runtimeType && \n',
            for (final field in fieldNames)
              ...[
                deepEquals,
                '(${field}, other.$field)',
                if (field != lastField) ' && \n'
              ],
            ';\n',
          ].indent(4),
          '\t}\n',
        ],
      ),
    );
  }
}

