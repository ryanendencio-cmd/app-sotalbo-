import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  try {
    var res = await http.get(Uri.parse('http://localhost:5000/api/workers/3'));
    stdout.writeln('STATUS: ${res.statusCode}');
    stdout.writeln('BODY: ${res.body}');
  } catch (e) {
    stderr.writeln('ERROR: $e');
  }
}
