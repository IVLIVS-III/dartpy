import 'dart:ffi';
import 'dart:io';

import 'package:dartpy/src/ffi/gen.dart';
import 'package:dartpy/src/ffi/utf32.dart';
import 'package:dartpy/src/helpers/error.dart';
import 'package:ffi/ffi.dart';

import '../dartpy_base.dart';
import 'bool_functions.dart';

export 'bool_functions.dart';
export 'converters/converters.dart';
export 'dart_py_object.dart';
export 'error.dart';

late Pointer<Utf32> _pprogramLoc, _pathString;

String get _pythonPath => dartpyc.Py_GetPath().cast<Utf32>().toDartString();

// TODO: change to ';' on windows
String get _pathDelimiter => ':';

Set<String> _customPathSegments = <String>{};

String? customPackagesPath;

void _ensureLatestPythonPath() {
  _ensureInitialized();
  print("[_ensureLatestPythonPath] got path: '$_pythonPath'");
  final pathSegments = _pythonPath.split(_pathDelimiter).toSet();
  pathSegments.addAll(_customPathSegments);
  pathSegments.add(Directory.current.absolute.path);
  pathSegments.add(pyLibLocation ?? '');
  final platformPythonPath = Platform.environment['PYTHONPATH'];
  pathSegments.add(platformPythonPath ?? '');
  final pathString =
      pathSegments.where((element) => element.isNotEmpty).join(_pathDelimiter);
  print("[_ensureLatestPythonPath] setting path to: '$pathString'");
  _pathString = pathString.toNativeUtf32();
  dartpyc.Py_SetPath(_pathString.cast<Int32>());
}

void _ensureCustomPackagesPath() {
  _ensureInitialized();
  print("[_ensureCustomPackagesPath] got packages path: '$customPackagesPath'");
  if (customPackagesPath != null) {
    // imports sys python module
    final pyModule = pyImport('sys');
    print(
        "[_ensureCustomPackagesPath] imported module sys @${pyModule._moduleRef.address.toRadixString(16)}");
    final pySysPath = dartpyc.PyObject_GetAttrString(
      pyModule._moduleRef,
      'path'.toNativeUtf8().cast<Int8>(),
    );
    print(
        "[_ensureCustomPackagesPath] got sys.path @${pySysPath.address.toRadixString(16)}");
    dartpyc.PyList_Append(
      pySysPath,
      pyConvertDynamic(customPackagesPath).pyObj,
    );
    print("[_ensureCustomPackagesPath] done");
  }
}

void addToPythonPath(String directory) {
  _customPathSegments.add(directory);
  _ensureLatestPythonPath();
}

/// Initializes the python runtime
void pyStart() {
  print("[pyStart] start");
  _pprogramLoc = 'python3'.toNativeUtf32();
  print("[pyStart] set _pprogramLoc");
  dartpyc.Py_SetProgramName(_pprogramLoc.cast<Int32>());
  print("[pyStart] set program name");
  dartpyc.Py_Initialize();
  print("[pyStart] called PyInitialize");
  _ensureLatestPythonPath();
  print("[pyStart] ensured latest python path");
  _ensureCustomPackagesPath();
  print("[pyStart] ensured custom packages path");
  if (pyErrOccurred()) {
    print('Error during initialization');
  }
  _ensureInitialized();
  print("[pyStart] ensured initialized");
}

void _ensureInitialized() {
  if (!pyInitialized) {
    dartpyc.Py_Initialize();
  }
}

/// Checks for python errors and throws a DartPyException in case there is one.
void ensureNoPythonError() {
  print("[ensureNoPythonError] start");
  if (pyErrOccurred()) {
    throw DartPyException.fetch();
  }
  print("[ensureNoPythonError] done");
}

/// Cleans up the memory of the loaded modules
void pyCleanup() {
  if (pyErrOccurred()) {
    print('Exited with python error:');
    dartpyc.PyErr_Print();
  }
  for (final mod in List.of(_moduleMap.values)) {
    mod.dispose();
  }
  dartpyc.Py_FinalizeEx();
  if (_pprogramLoc != nullptr) {
    malloc.free(_pprogramLoc);
  }
  if (_pathString != nullptr) {
    malloc.free(_pathString);
  }
}

final _moduleMap = <String, DartPyModule>{};

/// Loads a python module
DartPyModule pyImport(String module) {
  _ensureInitialized();
  if (_moduleMap.containsKey(module)) {
    return _moduleMap[module]!;
  }
  final mstring = module.toNativeUtf8();
  final pyString = dartpyc.PyUnicode_DecodeFSDefault(mstring.cast<Int8>());
  malloc.free(mstring);
  final pyImport = dartpyc.PyImport_Import(pyString);
  dartpyc.Py_DecRef(pyString);
  if (pyImport != nullptr) {
    final _mod = DartPyModule(module, pyImport);
    _moduleMap[module] = _mod;
    return _mod;
  } else {
    throw PackageDartpyException(
        'Importing python module $module failed, make sure the $module is on your PYTHONPATH\n eg. export PYTHONPATH=\$PYTHONPATH:/path/to/$module');
  }
}

/// A dart representation for the python module
class DartPyModule {
  DartPyModule(this.moduleName, this._moduleRef);

  final String moduleName;
  final Pointer<PyObject> _moduleRef;
  final Map<String, DartPyFunction> _functions = {};
  final Map<String, DartPyClass> _classes = {};

  /// Gets a function from the module
  DartPyFunction getFunction(String name) {
    if (_functions.containsKey(name)) {
      return _functions[name]!;
    }
    final funcName = name.toNativeUtf8();
    final pFunc =
        dartpyc.PyObject_GetAttrString(_moduleRef, funcName.cast<Int8>());
    malloc.free(funcName);
    if (pFunc != nullptr) {
      if (pFunc.isCallable) {
        _functions[name] = DartPyFunction(pFunc);
        return _functions[name]!;
      } else {
        dartpyc.Py_DecRef(pFunc);
        throw PackageDartpyException('$name is not callable');
      }
    } else {
      throw PackageDartpyException(
          'Function $name not found in module $moduleName');
    }
  }

  /// Gets a class from the module
  DartPyClass getClass(String name) {
    if (_classes.containsKey(name)) {
      return _classes[name]!;
    }
    final className = name.toNativeUtf8();
    final pClass =
        dartpyc.PyObject_GetAttrString(_moduleRef, className.cast<Int8>());
    malloc.free(className);
    if (pClass != nullptr) {
      _classes[name] = DartPyClass(name, pClass);
      return _classes[name]!;
    } else {
      throw PackageDartpyException(
          'Class $name not found in module $moduleName');
    }
  }

  /// Disposes the python module
  void dispose() {
    _moduleMap.remove(moduleName);
    for (final func in _functions.entries) {
      func.value.dispose();
    }
    _functions.clear();
    dartpyc.Py_DecRef(_moduleRef);
  }

  @override
  dynamic noSuchMethod(Invocation inv) {
    final invokeMethod = inv.memberName.toString();
    // inv.memberName is a Symbol and the toString() == Symbol("foo")
    return getFunction(
            invokeMethod.substring('Symbol("'.length, invokeMethod.length - 2))
        .call(inv.positionalArguments.cast<Object?>());
  }
}

/// A dart representation for the python class
class DartPyClass {
  DartPyClass(this.className, this._classRef);

  final String className;
  final Pointer<PyObject> _classRef;
  final Map<String, DartPyFunction> _functions = {};

  /// Gets a function from the class
  DartPyFunction getFunction(String name) {
    if (_functions.containsKey(name)) {
      return _functions[name]!;
    }
    final funcName = name.toNativeUtf8();
    final pFunc =
        dartpyc.PyObject_GetAttrString(_classRef, funcName.cast<Int8>());
    malloc.free(funcName);
    if (pFunc != nullptr) {
      if (pFunc.isCallable) {
        _functions[name] = DartPyFunction(pFunc);
        return _functions[name]!;
      } else {
        dartpyc.Py_DecRef(pFunc);
        throw PackageDartpyException('$name is not callable');
      }
    } else {
      throw PackageDartpyException(
          'Function $name not found in class $className');
    }
  }

  /// Disposes the python class
  void dispose() {
    _moduleMap.remove(className);
    for (final func in _functions.entries) {
      func.value.dispose();
    }
    _functions.clear();
    dartpyc.Py_DecRef(_classRef);
  }

  @override
  dynamic noSuchMethod(Invocation inv) {
    final invokeMethod = inv.memberName.toString();
    // inv.memberName is a Symbol and the toString() == Symbol("foo")
    return getFunction(
            invokeMethod.substring('Symbol("'.length, invokeMethod.length - 2))
        .call(inv.positionalArguments.cast<Object?>());
  }
}

/// A dart representation of a python function
class DartPyFunction {
  final Pointer<PyObject> _function;
  final List<Pointer<PyObject>> _argumentAllocations = [];

  Pointer<PyObject> get pyFunctionObject => _function;

  DartPyFunction(this._function);

  /// Disposes of the function
  void dispose() {
    disposeArguments();
    dartpyc.Py_DecRef(_function);
  }

  /// Disposes of the arguments to the function
  void disposeArguments() {
    for (final arg in _argumentAllocations) {
      dartpyc.Py_DecRef(arg);
    }
    _argumentAllocations.clear();
  }
}

extension CallableClassPyObjectList on DartPyClass {
  /// Calls the python class (constructor) with dart args marshalled back and forth
  Object? call(List<Object?> args, {Map<String, Object?>? kwargs}) =>
      DartPyObject.staticCall(_classRef, args: args, kwargs: kwargs);

  /// Calls the python class (constructor) with raw pyObject args and kwargs
  Pointer<PyObject> rawCall({
    List<Pointer<PyObject>>? args,
    Map<String, Pointer<PyObject>>? kwargs,
  }) =>
      DartPyObject.staticRawCall(_classRef, args: args, kwargs: kwargs);
}

extension CallablePyObjectList on DartPyFunction {
  /// Calls the python function with dart args marshalled back and forth
  Object? call(List<Object?> args, {Map<String, Object?>? kwargs}) =>
      DartPyObject.staticCall(_function, args: args, kwargs: kwargs);

  /// Calls the python function with raw pyObject args and kwargs
  Pointer<PyObject> rawCall({
    List<Pointer<PyObject>>? args,
    Map<String, Pointer<PyObject>>? kwargs,
  }) =>
      DartPyObject.staticRawCall(_function, args: args, kwargs: kwargs);
}
