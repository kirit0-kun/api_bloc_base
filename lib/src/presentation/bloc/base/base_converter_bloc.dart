import 'dart:async';

import 'package:async/async.dart';
import 'package:async/async.dart' as async;
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../base_provider/base_provider_bloc.dart' as provider;
import 'base_working_bloc.dart';

export 'working_state.dart';

abstract class BaseConverterBloc<Input, Output>
    extends BaseWorkingBloc<Output> {
  StreamSubscription _subscription;

  StreamSubscription _inputSubscription;

  get initialState => LoadingState();

  Stream<provider.ProviderState<Input>> get source => sourceBloc?.stateStream;

  final provider.BaseProviderBloc<Input> sourceBloc;

  final _eventsSubject =
      StreamController<provider.ProviderState<Input>>.broadcast();
  StreamSink<provider.ProviderState<Input>> get eventSink =>
      _eventsSubject.sink;
  Stream<provider.ProviderState<Input>> get eventStream =>
      async.LazyStream(() => _eventsSubject.stream
          .asBroadcastStream(onCancel: (sub) => sub.cancel()));
  final _statesSubject = BehaviorSubject<BlocState<Output>>();
  Stream<BlocState<Output>> get stateStream =>
      async.LazyStream(() => _statesSubject.shareValue());

  final _inputSubject = StreamController<Input>.broadcast();
  Stream<Input> get inputStream => LazyStream(() => _inputSubject.stream);
  StreamSink<Input> get inputSink => _inputSubject.sink;

  BaseConverterBloc({Output currentData, this.sourceBloc})
      : super(currentData) {
    listen((state) {
      _statesSubject.add(state);
    });
    _inputSubscription = inputStream.listen(handleData, onError: (e, s) {
      print(e);
      print(s);
      emit(ErrorState(defaultError));
    });
    _subscription = eventStream.listen(handleEvent, onError: (e, s) {
      print(this);
      print(e);
      print(s);
      emit(ErrorState(defaultError));
    });
    source?.pipe(eventSink);
  }

  void clean() {
    currentData = null;
  }

  Output Function(Input input) get converter => null;

  void handleEvent(provider.ProviderState event) {
    if (event is provider.ProviderLoadingState<Input>) {
      handleLoadingState(event);
    } else if (event is provider.ProviderLoadedState<Input>) {
      handleData(event.data);
    } else if (event is provider.ProviderErrorState<Input>) {
      handleErrorState(event);
    }
  }

  @mustCallSuper
  void handleErrorState(provider.ProviderErrorState<Input> errorState) {
    emit(ErrorState<Output>(errorState.message));
  }

  @mustCallSuper
  void handleLoadingState(provider.ProviderLoadingState<Input> loadingState) {
    emitLoading();
  }

  @mustCallSuper
  void handleData(Input event) {
    if (event == null) {
      emit(ErrorState<Output>(notFoundMessage));
    } else {
      setData(converter(event));
    }
  }

  @mustCallSuper
  void setData(Output newData) {
    currentData = newData;
    emitLoaded();
  }

  @mustCallSuper
  Future<Output> getData([bool refresh = false]) async {
    if (!refresh) emitLoading();
    return null;
  }

  Future<Output> reset() async {
    currentData = null;
    return getData();
  }

  @mustCallSuper
  Future<Output> refresh() async {
    sourceBloc?.refresh();
    return getData(true);
  }

  @override
  Future<void> close() {
    _inputSubscription?.cancel();
    _subscription?.cancel();
    _inputSubject.close();
    _statesSubject.drain().then((value) => _statesSubject.close());
    _eventsSubject.close();
    return super.close();
  }
}
