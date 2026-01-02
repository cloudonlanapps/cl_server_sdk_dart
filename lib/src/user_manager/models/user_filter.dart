/// Options for filtering user listings
class UserListOptions {
  UserListOptions({
    this.skip = 0,
    this.limit = 100,
    this.showAll = false,
  });

  /// Number of users to skip (for pagination)
  final int skip;

  /// Number of users to return (for pagination)
  final int limit;

  /// If false: show only utility-created users (with prefix)
  /// If true: show all users including system users
  final bool showAll;

  @override
  String toString() {
    return 'UserListOptions(skip: $skip, limit: $limit, showAll: $showAll)';
  }
}
