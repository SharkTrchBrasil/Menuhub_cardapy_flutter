sealed class PageStatus {}

class PageStatusIdle extends PageStatus {}
class PageStatusLoading extends PageStatus {}
class PageStatusError extends PageStatus {
  PageStatusError(this.message);
  final String message;
}
class PageStatusEmpty extends PageStatus {
  PageStatusEmpty(this.message);
  final String message;
}
class PageStatusSuccess<T> extends PageStatus {
  T data;

  PageStatusSuccess(this.data);
}