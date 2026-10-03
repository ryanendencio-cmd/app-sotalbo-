import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    var res = await http.get(Uri.parse('http://localhost:5000/api/workers'));
    if (res.statusCode == 200) {
      var data = jsonDecode(res.body) as List;
      for (var w in data) {
        print('ID: ${w['id']}, Name: ${w['full_name']}, Phone: ${w['phone']}, Approval: ${w['approval_status']}');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
}
