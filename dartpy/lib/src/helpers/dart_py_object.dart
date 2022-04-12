import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../dartpy_base.dart';

/// A dart class wrapping a python object
class DartPyObject {
  DartPyObject(this._pyObject);

  final Pointer<PyObject> _pyObject;

  Pointer<PyObject> get pyObject => _pyObject;

  Pointer<PyObject> rawGetAttribute(String name) {
    print("[rawGetAttribute] start");
    final result = dartpyc.PyObject_GetAttrString(
      _pyObject,
      name.toNativeUtf8().cast<Int8>(),
    );
    if (result == nullptr) {
      // check for errors
      ensureNoPythonError();
    }
    print("[rawGetAttribute] done");
    return result;
  }

  T getAttribute<T>(String name) =>
      pyConvertBackDynamic(rawGetAttribute(name)) as T;

  static T staticCall<T>(Pointer<PyObject> callable,
      {List<Object?>? args, Map<String, Object?>? kwargs}) {
    final pyObjs = <PyObjAllocated>[];

    // prepare args
    final pArgs = args
        ?.map((e) => pyConvertDynamicAndAddToList(e, pyObjs))
        .map((e) => e.pyObj)
        .toList();

    // prepare kwargs
    final pKwargs = kwargs?.map((key, value) =>
        MapEntry(key, pyConvertDynamicAndAddToList(value, pyObjs).pyObj));

    // call function
    final result = staticRawCall(callable, args: pArgs, kwargs: pKwargs);
    pyObjs.forEach((p) => p.dealloc());

    return pyConvertBackDynamic(result)! as T;
  }

  T call<T>(String name, {List<Object?>? args, Map<String, Object?>? kwargs}) {
    final callable = rawGetAttribute(name);
    return staticCall(callable, args: args, kwargs: kwargs);
  }

  /// Calls the python function with raw pyObject args and kwargs
  static Pointer<PyObject> staticRawCall(
    Pointer<PyObject> callable, {
    List<Pointer<PyObject>>? args,
    Map<String, Pointer<PyObject>>? kwargs,
  }) {
    final pyKeys = <PyObjAllocated>[];

    // prepare args
    final argsLen = args?.length ?? 0;
    final pArgs = dartpyc.PyTuple_New(argsLen);
    if (pArgs == nullptr) {
      throw PackageDartpyException('Creating argument tuple failed');
    }
    for (var i = 0; i < argsLen; i++) {
      dartpyc.PyTuple_SetItem(pArgs, i, args![i]);
    }

    // prepare kwargs
    late final Pointer<PyObject> pKwargs;
    if (kwargs == null) {
      pKwargs = nullptr;
    } else {
      pKwargs = dartpyc.PyDict_New();
      if (pKwargs == nullptr) {
        throw PackageDartpyException('Creating keyword argument dict failed');
      }
      for (final kwarg in kwargs.entries) {
        final kwargKey = pyConvertDynamicAndAddToList(kwarg.key, pyKeys).pyObj;
        dartpyc.PyDict_SetItem(pKwargs, kwargKey, kwarg.value);
      }
    }

    print("[staticRawCall] prepared kwargs");

    // call function
    print("[staticRawCall] calling function@${callable.address.toRadixString(16)}");
    final result = dartpyc.PyObject_Call(callable, pArgs, pKwargs);
    print("[staticRawCall] called function@${callable.address.toRadixString(16)}");
    pyKeys.forEach((p) => p.dealloc());
    print("[staticRawCall] dealloced keys");
    dartpyc.Py_DecRef(pArgs);
    print("[staticRawCall] decref-ed pArgs");
    if (pKwargs != nullptr) {
      dartpyc.Py_DecRef(pKwargs);
      print("[staticRawCall] decref-ed pKwargs");
    }


    // check for errors
    ensureNoPythonError();

    return result;
  }

  /// Calls the python function with raw pyObject args and kwargs
  Pointer<PyObject> rawCall(
    String name, {
    List<Pointer<PyObject>>? args,
    Map<String, Pointer<PyObject>>? kwargs,
  }) {
    print("[rawCall] start");
    print("[rawCall] converting name $name to callable");
    final callable = rawGetAttribute(name);
    print(
        "[rawCall] converted name $name to callable@${callable.address.toRadixString(16)}");
    print("[rawCall] executing staticRawCall");
    final result = staticRawCall(callable, args: args, kwargs: kwargs);
    print("[rawCall] executed staticRawCall");
    print("[rawCall] done");
    return result;
  }
}
