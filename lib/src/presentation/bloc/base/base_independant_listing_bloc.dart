import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:api_bloc_base/src/presentation/bloc/base/independant_mixin.dart';

import '../../../../api_bloc_base.dart';
import '../base_provider/provider_state.dart' as provider;

export 'working_state.dart';

abstract class _IndependentMediator<Output> extends BaseConverterBloc<Output, Output> {}

abstract class BaseIndependentListingBloc<Output, Filtering extends FilterType>
    extends BaseListingBloc<Output, Filtering> with IndependentMixin<Output> {

  final List<Stream<provider.ProviderState>> sources;

  get source => CombineLatestStream.combine3<ProviderState<Output>, Filtering,
      String, ProviderState<Output>>(
      super.source, filterStream, queryStream, (a, b, c) => a)
      .asBroadcastStream(onCancel: (sub) => sub.cancel());

  BaseIndependentListingBloc(
      {int searchDelayMillis = 1000,
      this.sources = const [],
      Output currentData})
      : super(currentData: currentData, searchDelayMillis: searchDelayMillis);

  Output Function(Output input) get converter =>
          (output) => applyFilter(output, filter, query);
}
