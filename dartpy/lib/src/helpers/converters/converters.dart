import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../dartpy_base.dart';
import '../bool_functions.dart';

export 'collections.dart';
export 'primitives.dart';

/// Converts a Dart object to the python equivalent
///
/// The caller of this function takes ownership of the python object
/// and must call Py_DecRef after they are done with it.
PyObjAllocated pyConvertDynamic(Object? o) {
  if (o == null) {
    return PyObjAllocated.noAllocation(dartpyc.Py_None);
  } else if (o is bool) {
    if (o) {
      return PyObjAllocated.noAllocation(dartpyc.Py_True);
    } else {
      return PyObjAllocated.noAllocation(dartpyc.Py_False);
    }
  } else if (o is int) {
    return PyObjAllocated.noAllocation(o.asPyInt);
  } else if (o is double) {
    return PyObjAllocated.noAllocation(o.asPyFloat);
  } else if (o is String) {
    return o.asPyBytes();
  } else if (o is List) {
    throw UnimplementedError();
  } else if (o is Map) {
    throw UnimplementedError();
  }
  throw UnimplementedError();
}

/// Convers a python object back to a dart representation
Object? pyConvertBackDynamic(Pointer<PyObject> result) {
  if (result == nullptr) {
    if (pyErrOccurred()) {
      dartpyc.PyErr_Print();
      throw UnimplementedError('Python error occurred');
    }
    return null;
  }

  if (result == dartpyc.Py_None) {
    dartpyc.Py_DecRef(result);
    return null;
  } else if (result.isBool) {
    if (result == dartpyc.Py_True) {
      dartpyc.Py_DecRef(result);
      return true;
    }
    dartpyc.Py_DecRef(result);
    return false;
  } else {
    final resultNameString =
        result.ref.ob_type.ref.tp_name.cast<Utf8>().toDartString();
    try {
      switch (resultNameString) {
        case 'str':
          final res = dartpyc.PyUnicode_AsUTF8String(result).asString;
          dartpyc.Py_DecRef(result);
          return res;
      }
    } on PackageDartpyException catch (_) {
      dartpyc.PyErr_Clear();
      print('Error while trying to convert via name string detection');
    }
    try {
      final res = result.asNum;
      dartpyc.Py_DecRef(result);
      return res;
    } on PackageDartpyException catch (_) {
      dartpyc.PyErr_Clear();
      try {
        final res = result.asString;
        dartpyc.Py_DecRef(result);
        return res;
      } on PackageDartpyException catch (_) {
        dartpyc.PyErr_Clear();
        throw PackageDartpyException(
            'Could not figure out the type of the object to convert back to: not a known primitive');
      }
    }
  }
}
