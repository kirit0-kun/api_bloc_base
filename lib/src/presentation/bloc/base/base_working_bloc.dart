import 'dart:async';

import 'package:api_bloc_base/src/data/model/remote/base_api_response.dart';
import 'package:api_bloc_base/src/data/repository/base_repository.dart';
import 'package:api_bloc_base/src/domain/entity/entity.dart';
import 'package:api_bloc_base/src/domain/entity/response_entity.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'base_converter_bloc.dart';

export 'working_state.dart';

abstract class BaseWorkingBloc<Output> extends Cubit<BlocState<Output>> {
  static const _DEFAULT_OPERATION = '_DEFAULT_OPERATION';

  String get notFoundMessage => 'foundNothing';
  String get loading => 'loading';
  String get defaultError => 'Error';

  Output currentData;

  BlocState<Output> get initialState => LoadedState(currentData);

  Map<String, Tuple3<String, CancelToken, Stream<double>>> _operationStack = {};

  BaseWorkingBloc(this.currentData) : super(LoadingState()) {
    emit(initialState);
  }

  void emitLoading() {
    emit(LoadingState<Output>());
  }

  void interceptOperation<S>(Result<Either<ResponseEntity, S>> result,
      {void onSuccess(), void onFailure(), void onDate(S data)}) {
    result.resultFuture.then((value) {
      value.fold((l) {
        if (l is Success) {
          onSuccess?.call();
        } else if (l is Failure) {
          onFailure?.call();
        }
      }, (r) {
        onSuccess?.call();
        onDate?.call(r);
      });
    });
  }

  void interceptResponse(Result<ResponseEntity> result,
      {void onSuccess(), void onFailure()}) {
    result.resultFuture.then((value) {
      if (value is Success) {
        onSuccess?.call();
      } else if (value is Failure) {
        onFailure?.call();
      }
    });
  }

  void checkOperations() {
    if (_operationStack.isNotEmpty && state is! Operation) {
      final item = _operationStack.entries.first;
      startOperation(item.value.value1, item.value.value2, item.value.value3,
          operationTag: item.key);
    }
  }

  Future<T> handleDataOperation<T extends Entity>(
      Result<Either<ResponseEntity, T>> result,
      {String loadingMessage,
      String successMessage,
      String operationTag = _DEFAULT_OPERATION}) async {
    startOperation(loadingMessage, result.cancelToken, result.progress,
        operationTag: operationTag);
    final future = await result.resultFuture;
    return future.fold<T>(
      (l) {
        handleResponse(l, operationTag: operationTag);
        return null;
      },
      (r) {
        successfulOperation(
          successMessage,
          operationTag: operationTag,
        );
        return r;
      },
    );
  }

  Future<Operation> handleOperation(Result<ResponseEntity> result,
      {String loadingMessage,
      String successMessage,
      String operationTag = _DEFAULT_OPERATION}) async {
    startOperation(loadingMessage, result.cancelToken, result.progress,
        operationTag: operationTag);
    final future = await result.resultFuture;
    return handleResponse(future, operationTag: operationTag);
  }

  Operation handleResponse(ResponseEntity l,
      {String operationTag = _DEFAULT_OPERATION,
      bool failure = true,
      bool success = true}) {
    if (l is Failure) {
      return failedOperation(l.message,
          doEmit: failure, errors: l.errors, operationTag: operationTag);
    } else if (l is Success) {
      return successfulOperation(l.message,
          doEmit: success, operationTag: operationTag);
    } else {
      removeOperation(operationTag: operationTag);
    }
    return null;
  }

  void emitLoaded() {
    emit(LoadedState<Output>(currentData));
  }

  void startOperation(
      String message, CancelToken token, Stream<double> progress,
      {String operationTag = _DEFAULT_OPERATION}) {
    message ??= loading;
    emit(OnGoingOperationState(
      data: currentData,
      loadingMessage: message,
      operationTag: operationTag,
      progress: progress,
    ));
    _operationStack[operationTag] = Tuple3(message, token, progress);
    checkOperations();
  }

  void cancelOperation({String operationTag = _DEFAULT_OPERATION}) {
    emitLoaded();
    final tuple = _operationStack.remove(operationTag);
    if (tuple.value2?.isCancelled == false) {
      tuple.value2.cancel();
    }
    checkOperations();
  }

  void removeOperation({String operationTag = _DEFAULT_OPERATION}) {
    _operationStack.remove(operationTag);
    emitLoaded();
    checkOperations();
  }

  Operation successfulOperation(String message,
      {bool doEmit = true, String operationTag = _DEFAULT_OPERATION}) {
    final op = SuccessfulOperationState(
        data: currentData, successMessage: message, operationTag: operationTag);
    if (doEmit) emit(op);
    _operationStack.remove(operationTag);
    checkOperations();
    return op;
  }

  FailedOperationState failedOperation(String message,
      {bool doEmit = true,
      BaseErrors errors,
      String operationTag = _DEFAULT_OPERATION}) {
    final op = FailedOperationState(
        data: currentData,
        errorMessage: message,
        operationTag: operationTag,
        errors: errors);
    if (doEmit) emit(op);
    _operationStack.remove(operationTag);
    checkOperations();
    return op;
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
