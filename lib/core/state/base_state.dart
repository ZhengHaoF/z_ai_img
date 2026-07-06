sealed class OperationState<T> {
  const OperationState();

  const factory OperationState.idle() = IdleState<T>;
  const factory OperationState.loading({double? progress}) = LoadingState<T>;
  const factory OperationState.success(T data) = SuccessState<T>;
  const factory OperationState.error(String message, {Object? error}) = ErrorState<T>;

  bool get isLoading => this is LoadingState;

  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  });
}

class IdleState<T> implements OperationState<T> {
  const IdleState();

  @override
  bool get isLoading => false;

  @override
  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  }) {
    return idle();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdleState<T>;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'OperationState.idle()';
}

class LoadingState<T> implements OperationState<T> {
  final double? progress;
  const LoadingState({this.progress});

  @override
  bool get isLoading => true;

  @override
  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  }) {
    return loading(progress);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingState<T> &&
          other.progress == progress;

  @override
  int get hashCode => progress.hashCode;

  @override
  String toString() => 'OperationState.loading(progress: $progress)';
}

class SuccessState<T> implements OperationState<T> {
  final T data;
  const SuccessState(this.data);

  @override
  bool get isLoading => false;

  @override
  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  }) {
    return success(data);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuccessState<T> &&
          other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'OperationState.success(data: $data)';
}

class ErrorState<T> implements OperationState<T> {
  final String message;
  final Object? error;
  const ErrorState(this.message, {this.error});

  @override
  bool get isLoading => false;

  @override
  R when<R>({
    required R Function() idle,
    required R Function(double? progress) loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  }) {
    return error(message, this.error);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorState<T> &&
          other.message == message &&
          other.error == error;

  @override
  int get hashCode => Object.hash(message, error);

  @override
  String toString() => 'OperationState.error(message: $message, error: $error)';
}
