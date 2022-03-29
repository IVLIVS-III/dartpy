import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../dartpy_base.dart';

/// A dart exception wrapping a python exception
class DartPyException extends DartPyObject implements Exception {
  DartPyException(Pointer<PyObject> pType, Pointer<PyObject> pValue,
      Pointer<PyObject> pTraceback)
      : pValue = pValue,
        pTraceback = pTraceback,
        super(pType);

  factory DartPyException.fetch() {
    final pTypePtr = malloc<Pointer<PyObject>>();
    final pValuePtr = malloc<Pointer<PyObject>>();
    final pTracebackPtr = malloc<Pointer<PyObject>>();
    dartpyc.PyErr_Fetch(pTypePtr, pValuePtr, pTracebackPtr);
    final dartPyException =
        DartPyException(pTypePtr.value, pValuePtr.value, pTracebackPtr.value);
    malloc.free(pTypePtr);
    malloc.free(pValuePtr);
    malloc.free(pTracebackPtr);
    return dartPyException;
  }

  Pointer<PyObject> get pType => pyObject;
  final Pointer<PyObject> pValue;
  final Pointer<PyObject> pTraceback;

  @override
  String toString() {
    print('trying to print DartPyException');
    final typeRepr = dartpyc.PyObject_Repr(pType).asUnicodeString;
    final valueRepr = dartpyc.PyObject_Repr(pValue).asUnicodeString;
    final tracebackRepr = dartpyc.PyObject_Repr(pTraceback).asUnicodeString;
    return 'DartPyException($typeRepr): $valueRepr\n$tracebackRepr';
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
