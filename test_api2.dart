import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  try {
    var res = await http.get(Uri.parse('http://localhost:5000/api/workers'));
    if (res.statusCode == 200) {
      var data = jsonDecode(res.body) as List;
      for (var w in data) {
        stdout.writeln('ID: ${w['id']}, Name: ${w['full_name']}, Phone: ${w['phone']}, Approval: ${w['approval_status']}');
      }
    }
  } catch (e) {
    stderr.writeln('ERROR: $e');
  }
}
