



class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result._({this.data, this.error, required this.isSuccess});

  
  factory Result.success(T data) {
    return Result._(data: data, isSuccess: true);
  }

  
  factory Result.error(String error) {
    return Result._(error: error, isSuccess: false);
  }

  
  bool get isError => !isSuccess;

  
  T get dataOrThrow {
    if (isError) {
      throw Exception(error ?? 'Unknown error');
    }
    return data as T;
  }

  
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

  
  Result<T> onError(void Function(String error) callback) {
    if (isError && error != null) {
      callback(error!);
    }
    return this;
  }

  
  Result<T> onSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
    return this;
  }
}
