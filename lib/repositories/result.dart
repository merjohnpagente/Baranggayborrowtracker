/// A small result type so repositories can return a value *or* a message
/// without throwing.
///
/// Signatures that return `Asset` and signal failure with exceptions force
/// every caller into a try/catch and make "did this fail, and why?" invisible
/// in the widget layer. [Result] makes the failure path explicit and keeps the
/// human-readable message next to the error.
sealed class Result<T> {
  const Result();

  /// True when the call succeeded.
  bool get isSuccess => this is Success<T>;

  /// True when the call failed.
  bool get isFailure => this is Failure<T>;

  /// The value, or null on failure.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// The error message, or null on success.
  String? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final message) => message,
      };

  /// Collapses both cases into a value, for the paths that already checked.
  T get requireValue => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>(:final message) =>
          throw StateError('Expected a value but got failure: $message'),
      };

  R fold<R>(R Function(T value) onSuccess, R Function(String error) onFailure) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final message) => onFailure(message),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      other is Success<T> && other.value == value;

  @override
  int get hashCode => Object.hash('Success', value);

  @override
  String toString() => 'Success($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.message == message;

  @override
  int get hashCode => Object.hash('Failure', message);

  @override
  String toString() => 'Failure($message)';
}