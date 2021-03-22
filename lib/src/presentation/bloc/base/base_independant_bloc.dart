import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../api_bloc_base.dart';
import '../base_provider/provider_state.dart' as provider;
import 'base_converter_bloc.dart';

export 'working_state.dart';

abstract class BaseIndependentBloc<Output>
    extends BaseConverterBloc<Output, Output> {
  final List<Stream<provider.ProviderState>> sources;

  BaseIndependentBloc({this.sources = const [], Output currentData})
      : super(currentData: currentData) {
    Stream<provider.ProviderState<Output>> finalStream;
    if (sources.isNotEmpty) {
      final stream = CombineLatestStream.list(sources).asBroadcastStream();
      finalStream = CombineLatestStream.combine2<List, Output,
              provider.ProviderState<Output>>(stream, originalDataStream,
          (list, data) {
        provider.ProviderErrorState error = list.firstWhere(
            (element) => element is provider.ProviderErrorState,
            orElse: () => null);
        if (error != null) {
          return provider.ProviderErrorState<Output>(error.message);
        }
        provider.ProviderLoadingState loading = list.firstWhere(
            (element) => element is provider.ProviderLoadingState,
            orElse: () => null);
        if (loading != null) {
          return provider.ProviderLoadingState<Output>();
        }
        provider.InvalidatedState invalidated = list.firstWhere(
            (element) => element is provider.InvalidatedState,
            orElse: () => null);
        if (invalidated != null) {
          return provider.InvalidatedState<Output>();
        }
        return provider.ProviderLoadedState<Output>(data);
      }).asBroadcastStream();
    } else {
      finalStream = originalDataStream
          .map((data) => provider.ProviderLoadedState<Output>(data))
          .asBroadcastStream();
    }
    finalStream.doOnEach((notification) => emitLoading()).listen(handleEvent);
  }

  Output combineData(Output data) => data;

  void handleData(Output event) {
    final data = combineData(event);
    super.handleData(data);
  }

  final _ownDataSubject = BehaviorSubject<Output>();
  Stream<Output> get originalDataStream => _ownDataSubject.shareValue();

  Output Function(Output input) get converter => (data) => data;
  Result<Either<ResponseEntity, Output>> get dataSource;

  void getData() {
    super.getData();
    final data = dataSource;
    handleDataRequest(data);
  }

  Future<Output> handleDataRequest(
      Result<Either<ResponseEntity, Output>> result) async {
    emitLoading();
    final future = await result.resultFuture;
    return future.fold<Output>(
      (l) {
        return null;
      },
      (r) {
        _ownDataSubject.add(r);
        return r;
      },
    );
  }

  @override
  Future<void> close() {
    _ownDataSubject.drain().then((value) => _ownDataSubject.close());
    return super.close();
  }
}
