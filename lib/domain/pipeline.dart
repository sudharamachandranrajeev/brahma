/// Steps of a car hunt, in order (labels in vehicles.dart).
enum Stage {
  fresh('new'),
  shortlisted('shortlisted'),
  enquired('enquired'),
  viewing('viewing'),
  applied('applied'),
  agreed('agreed'),
  dropped('dropped');

  const Stage(this.id);
  final String id;

  static Stage of(String id) => values.where((s) => s.id == id).firstOrNull ?? fresh;

  /// Still in play.
  bool get active => this != dropped;
}
