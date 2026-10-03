import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    var res = await http.get(Uri.parse('http://localhost:5000/api/workers/3'));
    print('STATUS: ${res.statusCode}');
    print('BODY: ${res.body}');
  } catch (e) {
    print('ERROR: $e');
  }
}
