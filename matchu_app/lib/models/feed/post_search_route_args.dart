class PostSearchRouteArgs {
  const PostSearchRouteArgs({required this.query});

  final String query;

  static PostSearchRouteArgs? tryParse(Object? arguments) {
    if (arguments is PostSearchRouteArgs) return arguments;
    if (arguments is String) {
      final query = arguments.trim();
      return query.isEmpty ? null : PostSearchRouteArgs(query: query);
    }
    if (arguments is Map) {
      final query = arguments['query']?.toString().trim() ?? '';
      return query.isEmpty ? null : PostSearchRouteArgs(query: query);
    }
    return null;
  }
}
