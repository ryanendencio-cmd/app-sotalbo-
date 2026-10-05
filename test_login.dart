import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    var res = await http.post(
      Uri.parse('http://localhost:5000/api/login'), 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode({'username': '09602643305', 'password': 'Mico1234'})
    );
    print('0960: ${res.statusCode} ${res.body}');
  } catch(e) {
    print(e);
  }

  try {
    var res2 = await http.post(
      Uri.parse('http://localhost:5000/api/login'), 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode({'username': '+6309602643305', 'password': 'Mico1234'})
    );
    print('+630960: ${res2.statusCode} ${res2.body}');
  } catch(e) {
    print(e);
  }

  try {
    var res3 = await http.post(
      Uri.parse('http://localhost:5000/api/login'), 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode({'username': '+639602643305', 'password': 'Mico1234'})
    );
    print('+63960: ${res3.statusCode} ${res3.body}');
  } catch(e) {
    print(e);
  }

  try {
    var res4 = await http.get(Uri.parse('http://localhost:5000/api/workers'));
    if (res4.statusCode == 200) {
      var data = jsonDecode(res4.body) as List;
      for (var w in data) {
        if (w['phone'] != null && w['phone'].toString().contains('9602643305')) {
            print('FOUND WORKER: ${w}');
        }
      }
    }
  } catch(e) {
    print(e);
  }
}
