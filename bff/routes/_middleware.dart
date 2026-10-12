import 'package:dart_frog/dart_frog.dart';

const _corsHeaders = <String, String>{
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'access-control-allow-headers': 'Origin, Content-Type, Authorization',
};

/// CORS para que la app también pueda probarse desde web (puerto distinto).
Handler middleware(Handler handler) {
  return (RequestContext context) async {
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: _corsHeaders);
    }
    final response = await handler(context);
    return response.copyWith(
      headers: {...response.headers, ..._corsHeaders},
    );
  };
}
