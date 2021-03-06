import 'dart:async';

import 'package:api_bloc_base/api_bloc_base.dart';
import 'package:api_bloc_base/src/presentation/bloc/base/independant_mixin.dart';
import 'package:api_bloc_base/src/presentation/bloc/user/base_user_bloc.dart';

mixin UserDependantMixin<Data> on IndependentMixin<Data> {
  BaseUserBloc get userBloc => null;
  String authToken;
  get userId => userBloc.currentUser?.id;
  StreamSubscription _subscription;

  void setUpUserListener() {
    _subscription = userBloc.userStream.listen(
      (user) {
        final newToken = user?.accessToken;
        if (newToken != null) {
          if (newToken != authToken) {
            authToken = newToken;
            reset();
          }
        } else {
          authToken = null;
        }
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
