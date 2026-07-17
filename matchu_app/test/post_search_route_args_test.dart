import 'package:flutter_test/flutter_test.dart';
import 'package:matchu_app/models/feed/post_search_route_args.dart';

void main() {
  test('parses typed, string and map search arguments', () {
    expect(
      PostSearchRouteArgs.tryParse(
        const PostSearchRouteArgs(query: 'flutter'),
      )?.query,
      'flutter',
    );
    expect(PostSearchRouteArgs.tryParse('  getx  ')?.query, 'getx');
    expect(
      PostSearchRouteArgs.tryParse({'query': 'firebase'})?.query,
      'firebase',
    );
  });

  test('rejects missing or blank query arguments', () {
    expect(PostSearchRouteArgs.tryParse(null), isNull);
    expect(PostSearchRouteArgs.tryParse('   '), isNull);
    expect(PostSearchRouteArgs.tryParse(const <String, Object?>{}), isNull);
  });
}
