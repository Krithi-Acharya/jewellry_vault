class ApiConstants {
  static const String login = '/auth/login';
  static const String syncUser = '/auth/sync-user';
  static const String me = '/auth/me';
  static const String closet = '/closet';
  static const String adminStats = '/admin/stats';
  static const String adminUsers = '/admin/users';
  static const String adminItems = '/admin/items';
  static const String adminQueue = '/admin/queue';
  static const String adminActivity = '/admin/activity';
  static String adminItemRetry(int id) => '/admin/items/$id/retry';
}
