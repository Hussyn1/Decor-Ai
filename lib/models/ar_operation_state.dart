/// Represents the current state of an asynchronous AR operation.
enum ArOperationStatus { idle, loading, success, error }

/// Holds the state and potential error message for an operation.
class ArOperationState {
  final ArOperationStatus status;
  final String? errorMessage;

  const ArOperationState({
    this.status = ArOperationStatus.idle,
    this.errorMessage,
  });

  factory ArOperationState.idle() =>
      const ArOperationState(status: ArOperationStatus.idle);

  factory ArOperationState.loading() =>
      const ArOperationState(status: ArOperationStatus.loading);

  factory ArOperationState.success() =>
      const ArOperationState(status: ArOperationStatus.success);

  factory ArOperationState.error(String message) =>
      ArOperationState(status: ArOperationStatus.error, errorMessage: message);

  bool get isLoading => status == ArOperationStatus.loading;
  bool get isError => status == ArOperationStatus.error;
  bool get isSuccess => status == ArOperationStatus.success;
}
