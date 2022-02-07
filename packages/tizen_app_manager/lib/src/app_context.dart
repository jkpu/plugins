// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: always_specify_types, public_member_api_docs

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

typedef _AppManagerGetAppContext = Int32 Function(
    Pointer<Utf8>, Pointer<Pointer<_ContextHandle>>);
typedef _AppManagerIsRunning = Int32 Function(Pointer<Utf8>, Pointer<Int8>);
typedef _AppContextGetPackageId = Int32 Function(
    Pointer<_ContextHandle>, Pointer<Pointer<Utf8>>);
typedef _AppContextGetPid = Int32 Function(
    Pointer<_ContextHandle>, Pointer<Int32>);
typedef _AppContextGetAppState = Int32 Function(
    Pointer<_ContextHandle>, Pointer<Int32>);
typedef _AppManagerTerminate = Int32 Function(Pointer<_ContextHandle>);
typedef _AppManagerResumeApp = Int32 Function(Pointer<_ContextHandle>);
typedef _AppContextDestroy = Int32 Function(Pointer<_ContextHandle>);

class _ContextHandle extends Opaque {}

const int tizenErrorNone = 0;
const int tizenErrorIOError = -5;
const int tizenErrorOutOfMemory = -12;
const int tizenErrorPermissionDenied = -13;
const int tizenErrorInvalidParameter = -22;
const int tizenErrorUnknown = -1073741824;
const int tizenErrorNotSupported = -1073741824 + 2;
const int tizenErrorApplicationManager = -0x01110000;
const int appManagerErrorNoSuchApp = tizenErrorApplicationManager | 0x01;
const int appManagerErrorDBFailed = tizenErrorApplicationManager | 0x03;
const int appManagerErrorInvalidPackage = tizenErrorApplicationManager | 0x04;
const int appManagerErrorAppNoRunning = tizenErrorApplicationManager | 0x05;
const int appManagerErrorRequestFailed = tizenErrorApplicationManager | 0x06;

const Map<int, String> _errorCodes = <int, String>{
  tizenErrorNone: 'APP_MANAGER_ERROR_NONE',
  tizenErrorIOError: 'APP_MANAGER_ERROR_IO_ERROR',
  tizenErrorOutOfMemory: 'APP_MANAGER_ERROR_OUT_OF_MEMORY',
  tizenErrorPermissionDenied: 'APP_MANAGER_ERROR_PERMISSION_DENIED',
  tizenErrorInvalidParameter: 'APP_MANAGER_ERROR_INVALID_PARAMETER',
  tizenErrorUnknown: 'APP_MANAGER_ERROR_IO_ERROR ',
  tizenErrorNotSupported: 'APP_MANAGER_ERROR_NOT_SUPPORTED ',
  appManagerErrorNoSuchApp: 'appManagerErrorNoSuchApp',
  appManagerErrorDBFailed: 'appManagerErrorDBFailed',
  appManagerErrorInvalidPackage: 'appManagerErrorInvalidPackage',
  appManagerErrorAppNoRunning: 'appManagerErrorAppNoRunning',
  appManagerErrorRequestFailed: 'appManagerErrorRequestFailed',
};

String _getErrorCode(int returnCode) => _errorCodes.containsKey(returnCode)
    ? _errorCodes[returnCode]!
    : '$returnCode';

_AppManager? _appManagerInstance;
_AppManager get appManager => _appManagerInstance ??= _AppManager();

class _AppManager {
  _AppManager() {
    final libAppMananger =
        DynamicLibrary.open('libcapi-appfw-app-manager.so.0');
    getAppContext = libAppMananger
        .lookup<NativeFunction<_AppManagerGetAppContext>>(
            'app_manager_get_app_context')
        .asFunction();
    appIsRunning = libAppMananger
        .lookup<NativeFunction<_AppManagerIsRunning>>('app_manager_is_running')
        .asFunction();
    getPackageId = libAppMananger
        .lookup<NativeFunction<_AppContextGetPackageId>>(
            'app_context_get_package_id')
        .asFunction();
    getProcessId = libAppMananger
        .lookup<NativeFunction<_AppContextGetPid>>('app_context_get_pid')
        .asFunction();
    getAppState = libAppMananger
        .lookup<NativeFunction<_AppContextGetAppState>>(
            'app_context_get_app_state')
        .asFunction();
    terminateApp = libAppMananger
        .lookup<NativeFunction<_AppManagerTerminate>>(
            'app_manager_terminate_app')
        .asFunction();
    resumeApp = libAppMananger
        .lookup<NativeFunction<_AppManagerResumeApp>>('app_manager_resume_app')
        .asFunction();
    destroyContext = libAppMananger
        .lookup<NativeFunction<_AppContextDestroy>>('app_context_destroy')
        .asFunction();
  }

  late int Function(Pointer<Utf8>, Pointer<Pointer<_ContextHandle>>)
      getAppContext;
  late int Function(Pointer<Utf8>, Pointer<Int8>) appIsRunning;
  late int Function(Pointer<_ContextHandle>, Pointer<Pointer<Utf8>>)
      getPackageId;
  late int Function(Pointer<_ContextHandle>, Pointer<Int32>) getProcessId;
  late int Function(Pointer<_ContextHandle>, Pointer<Int32>) getAppState;
  late int Function(Pointer<_ContextHandle>) terminateApp;
  late int Function(Pointer<_ContextHandle>) resumeApp;
  late int Function(Pointer<_ContextHandle>) destroyContext;
}

class AppContext {
  AppContext(String appId, int handleAddress) {
    if (appId.isEmpty) {
      throw ArgumentError('Must not be empty', 'appId');
    }

    _appId = appId;
    if (handleAddress == 0) {
      final Pointer<Pointer<_ContextHandle>> pHandle = malloc();
      final pAppId = appId.toNativeUtf8();
      try {
        final ret = appManager.getAppContext(pAppId, pHandle);
        if (ret != 0) {
          throw PlatformException(
            message: 'Failed to excute app_manager_get_app_context $appId',
            code: _getErrorCode(ret),
          );
        }
        _handle = pHandle.value;
      } finally {
        malloc.free(pAppId);
        malloc.free(pHandle);
      }
    } else {
      // if have app_context_h
      _handle = Pointer.fromAddress(handleAddress);
    }
  }

  Pointer<_ContextHandle> _handle = nullptr;
  late String _appId;

  void destroy() {
    if (_handle != nullptr) {
      final ret = appManager.destroyContext(_handle);
      _handle = nullptr;
      if (ret != 0) {
        throw PlatformException(
          message: 'Failed to excute app_context_destroy',
          code: _getErrorCode(ret),
        );
      }
    }
  }

  bool isAppRunning() {
    final Pointer<Int8> out = malloc();
    final pAppId = _appId.toNativeUtf8();
    try {
      final ret = appManager.appIsRunning(pAppId, out);
      if (ret != 0) {
        throw PlatformException(
          message: 'Failed to excute app_manager_is_running $_appId',
          code: _getErrorCode(ret),
        );
      }

      return out.value != 0;
    } finally {
      malloc.free(pAppId);
      malloc.free(out);
    }
  }

  String getPackageId() {
    final Pointer<Pointer<Utf8>> packageIdP = malloc();
    try {
      _checkHandle();
      final ret = appManager.getPackageId(_handle, packageIdP);
      if (ret != 0) {
        throw PlatformException(
          message: 'Failed to excute app_context_get_package_id',
          code: _getErrorCode(ret),
        );
      }

      return packageIdP.value.toDartString();
    } finally {
      malloc.free(packageIdP);
    }
  }

  int getProcessId() {
    final Pointer<Int32> processIdP = malloc();
    try {
      _checkHandle();
      final ret = appManager.getProcessId(_handle, processIdP);
      if (ret != 0) {
        throw PlatformException(
          message: 'Failed to execute app_context_get_pid',
          code: _getErrorCode(ret),
        );
      }
      return processIdP.value;
    } finally {
      malloc.free(processIdP);
    }
  }

  int getAppState() {
    final Pointer<Int32> stateP = malloc();
    try {
      _checkHandle();
      final ret = appManager.getAppState(_handle, stateP);
      if (ret != 0) {
        throw PlatformException(
          message: 'Failed to excute app_context_get_app_state',
          code: _getErrorCode(ret),
        );
      }
      return stateP.value;
    } finally {
      malloc.free(stateP);
    }
  }

  void terminate() {
    _checkHandle();
    final ret = appManager.terminateApp(_handle);
    if (ret != 0) {
      throw PlatformException(
        message: 'Failed to excute app_manager_terminate_app',
        code: _getErrorCode(ret),
      );
    }
  }

  void resume() {
    _checkHandle();
    final ret = appManager.resumeApp(_handle);
    if (ret != 0) {
      throw PlatformException(
        message: 'Failed to excute app_manager_resume_app',
        code: _getErrorCode(ret),
      );
    }
  }

  void _checkHandle() {
    if (_handle == nullptr) {
      throw StateError('The handle object has been destroyed');
    }
  }
}
