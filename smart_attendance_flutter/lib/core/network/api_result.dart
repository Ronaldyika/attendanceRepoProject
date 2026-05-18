class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const ApiResult.success(this.data)
      : error = null,
        isSuccess = true;

  const ApiResult.failure(this.error)
      : data = null,
        isSuccess = false;

  @override
  String toString() => isSuccess ? 'Success($data)' : 'Failure($error)';
}
