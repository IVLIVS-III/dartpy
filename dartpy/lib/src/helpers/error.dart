import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../dartpy_base.dart';
import 'dart_py_object.dart';

/// A dart exception wrapping a python exception
class DartPyException extends DartPyObject implements Exception {
  DartPyException(Pointer<PyObject> pyException) : super(pyException);

  Pointer<PyObject> get pyException => pyObject;

  @override
  String toString() {
    return 'DartPyException(${pyException.ref.ob_type.ref.tp_name.cast<Utf8>().toDartString()})';
  }
}

/// An exception to be thrown when something goes wrong in package code.
class PackageDartpyException implements Exception {
  String message;

  PackageDartpyException(this.message);

  @override
  String toString() {
    return 'PackageDartpyException($message)';
  }
}
