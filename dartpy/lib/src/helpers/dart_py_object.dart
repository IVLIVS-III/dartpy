import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../dartpy_base.dart';

/// A dart class wrapping a python object
class DartPyObject {
  DartPyObject(this._pyObject);

  final Pointer<PyObject> _pyObject;

  Pointer<PyObject> get pyObject => _pyObject;

  Pointer<PyObject> rawGetAttribute(String name) {
    final result = dartpyc.PyObject_GetAttrString(
      _pyObject,
      name.toNativeUtf8().cast<Int8>(),
    );
    return result;
  }

  T getAttribute<T>(String name) =>
      pyConvertBackDynamic(rawGetAttribute(name)) as T;

  T call<T>(String name, {List<Object?>? args, Map<String, Object?>? kwargs}) {
    final effectiveArgs = args ?? <Object?>[];
    final effectiveKwargs = kwargs ?? <String, Object?>{};

    // prepare args
    final pArgs = dartpyc.PyTuple_New(effectiveArgs.length);
    if (pArgs == nullptr) {
      throw PackageDartpyException('Creating argument tuple failed');
    }
    final pyObjs = <PyObjAllocated<NativeType>>[];
    for (var i = 0; i < effectiveArgs.length; i++) {
      PyObjAllocated<NativeType>? arg;
      try {
        arg = pyConvertDynamic(effectiveArgs[i]);
        dartpyc.PyTuple_SetItem(pArgs, i, arg.pyObj);
      } on PackageDartpyException catch (e) {
        if (arg != null) {
          dartpyc.Py_DecRef(arg.pyObj);
        }
        dartpyc.Py_DecRef(pArgs);
        throw PackageDartpyException(
          'Failed while converting argument ${effectiveArgs[i]} with error $e',
        );
      }
    }

    // prepare kwargs
    final pKwargs = dartpyc.PyDict_New();
    if (pKwargs == nullptr) {
      throw PackageDartpyException('Creating keyword argument dict failed');
    }
    for (final MapEntry<String, dynamic> kwarg in effectiveKwargs.entries) {
      PyObjAllocated<NativeType>? kwargKey;
      PyObjAllocated<NativeType>? kwargValue;
      try {
        kwargKey = pyConvertDynamic(kwarg.key);
        kwargValue = pyConvertDynamic(kwarg.value);
        dartpyc.PyDict_SetItem(pKwargs, kwargKey.pyObj, kwargValue.pyObj);
      } on PackageDartpyException catch (e) {
        if (kwargKey != null) {
          dartpyc.Py_DecRef(kwargKey.pyObj);
        }
        if (kwargValue != null) {
          dartpyc.Py_DecRef(kwargValue.pyObj);
        }
        dartpyc
          ..Py_DecRef(pArgs)
          ..Py_DecRef(pKwargs);
        throw PackageDartpyException(
          'Failed while converting keyword argument ${kwarg.key}: ${kwarg.value} with error $e',
        );
      }
    }

    // call function
    final function = rawGetAttribute(name);
    final result = dartpyc.PyObject_Call(function, pArgs, pKwargs);

    for (final p in pyObjs) {
      p.dealloc();
    }
    dartpyc
      ..Py_DecRef(pArgs)
      ..Py_DecRef(pKwargs);

    // check for errors
    final errorPtr = dartpyc.PyErr_Occurred();
    if (errorPtr != nullptr) {
      throw DartPyException(errorPtr);
    }

    return pyConvertBackDynamic(result) as T;
  }
}
