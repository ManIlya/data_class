import 'dart:async';

import 'package:macros/macros.dart';
import 'copy_with.dart';
import 'constructable.dart';
import 'equtable.dart';
import 'stringable.dart';

macro class DataClass implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const DataClass();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    await Constructable().buildDeclarationsForClass(clazz, builder);
    await CopyWith().buildDeclarationsForClass(clazz, builder);
    await ToStringable().buildDeclarationsForClass(clazz, builder);
    await Equatable().buildDeclarationsForClass(clazz, builder);
  }

  @override
  Future<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder builder) async {
    await CopyWith().buildDefinitionForClass(clazz, builder);
    await ToStringable().buildDefinitionForClass(clazz, builder);
    await Equatable().buildDefinitionForClass(clazz, builder);
  }

}