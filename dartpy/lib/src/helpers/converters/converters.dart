import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../dartpy_base.dart';
import '../bool_functions.dart';

export 'collections.dart';
export 'primitives.dart';

String _toString(Pointer<PyObject> obj) {
  return dartpyc.PyUnicode_AsUTF8String(obj).asString;
}

ByteData _toByteData(Pointer<PyObject> obj) {
  final length = dartpyc.PySequence_Length(obj);
  final bytes = ByteData(length);
  for (var i = 0; i < length; i++) {
    final item = dartpyc.PySequence_GetItem(obj, i);
    bytes.setInt32(i, item.asInt);
  }

  return bytes;
}

Map<String, Object? Function(Pointer<PyObject>)> _fromPyObjectConversions =
    <String, Object? Function(Pointer<PyObject>)>{
  'str': _toString,
  'bytes': _toByteData,
};
// TODO: extend the conversion method for other arbitrary objects
//       necessary:
//         - List<T>
//         - Tuple<T> -> List<T>
//         - Dict<T1, T2> -> Map<T1, T2>
//         - Object -> WrappedPyObject
//         - URL -> Uri
//         - bytes -> ByteData
//         - datetime.timedelta -> Duration

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
    return o.asPyUnicode();
  } else if (o is List) {
    throw UnimplementedError();
  } else if (o is Map) {
    throw UnimplementedError();
  }
  throw UnimplementedError();
}

PyObjAllocated<NativeType> pyConvertDynamicAndAddToList(
  value,
  List<PyObjAllocated> pyObjs,
) {
  PyObjAllocated<NativeType>? converted;
  try {
    converted = pyConvertDynamic(value);
  } on PackageDartpyException catch (e) {
    if (converted != null) {
      dartpyc.Py_DecRef(converted.pyObj);
    }
    throw PackageDartpyException(
        'Failed while converting $value with error $e');
  }
  pyObjs.add(converted);
  return converted;
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
      // TODO: add other conversions to _fromPyObjectConversions
      if (_fromPyObjectConversions.containsKey(resultNameString)) {
        final conversion = _fromPyObjectConversions[resultNameString];
        if (conversion != null) {
          final res = conversion(result);
          dartpyc.Py_DecRef(result);
          return res;
        }
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
