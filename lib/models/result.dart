/// Result wrapper for operations that can succeed or fail
///
/// Provides a type-safe way to handle success and error cases
/// without throwing exceptions.
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result._({this.data, this.error, required this.isSuccess});

  /// Create a successful result with data
  factory Result.success(T data) {
    return Result._(data: data, isSuccess: true);
  }

  /// Create a failed result with an error message
  factory Result.error(String error) {
    return Result._(error: error, isSuccess: false);
  }

  /// Check if the result is an error
  bool get isError => !isSuccess;

  /// Get the data or throw if error
  T get dataOrThrow {
    if (isError) {
      throw Exception(error ?? 'Unknown error');
    }
    return data as T;
  }

  /// Execute a function if successful, otherwise return the error
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return Result.success(transform(data as T));
      } catch (e) {
        return Result.error(e.toString());
      }
    }
    return Result.error(error ?? 'No data available');
  }

  /// Execute a function if error
  Result<T> onError(void Function(String error) callback) {
    if (isError && error != null) {
      callback(error!);
    }
    return this;
  }

  /// Execute a function if successful
  Result<T> onSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
    return this;
  }
}
