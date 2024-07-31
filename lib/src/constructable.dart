import 'dart:async';

import 'package:data_class/src/extensions/buider_extension.dart';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';

macro class Constructable
    with _Constructable
    implements ClassDeclarationsMacro {

  const Constructable();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    await _declareNamedConstructor(clazz, builder);
  }

}

mixin _Constructable{

  Future<void> _declareNamedConstructor(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    final defaultConstructor = await builder.defaultConstructorOf(clazz);
    if (defaultConstructor != null) return;

    final superClassAnnotation = clazz.superclass;
    ConstructorParams superclassConstructorParams = (positional: [], named: []);
    final superclass = await superClassAnnotation?.classDeclaration(builder);
    if (superclass != null) {
      final defaultSuperConstructor = await builder.defaultConstructorOf(
          superclass);
      if (defaultSuperConstructor == null) {
        builder.reportError(
          '${superclass.identifier.name} must have a default constructor',
          target: superclass.asDiagnosticTarget,);
        return;
      }
      superclassConstructorParams =
      await builder.constructorParamsOf(defaultSuperConstructor, superclass);
    }
    final superclassParams = [
      ...superclassConstructorParams.positional,
      ...superclassConstructorParams.named,
    ];
    if (superclassParams.any((p) => p.type == null)) return null;
    final fields = await builder.fieldsOf(clazz);

    // Exclude static fields.
    fields.removeWhere((f) => f.hasStatic);

    // Ensure all class fields have a type.
    if (fields.any((f) => f.type.checkNamed(builder) == null)) return null;

    if (fields.isEmpty && superclassParams.isEmpty) {
      return builder.declareInType(
        DeclarationCode.fromString('const ${clazz.identifier.name}();'),
      );
    }

    builder.declareInType(DeclarationCode.fromParts([
      '${clazz.identifier.name}({\n',
      for (final parameter in superclassParams)
        ...[
          if (parameter.isRequired) 'required ',
          parameter.type!.code,
          ' ${parameter.name},\n'
        ].indent(),
      for( final field in fields)
        ...[
          if (!field.type.isNullable) 'required ',
          'this.${field.identifier.name},\n'
        ].indent(),
      '})',
      if(superclass != null)
        ...[
          ': super(\n',
          for (final param in superclassConstructorParams.positional)
            ...['', param.name, ',\n'].indent(),
          for (final param in superclassConstructorParams.named)
            ...['', param.name, ': ', param.name, ',\n'].indent(),
          ')',
        ],
      ';\n'
    ].indent()));
  }
}

extension on NamedTypeAnnotation? {
  classDeclaration(MemberDeclarationBuilder builder) {}
}

