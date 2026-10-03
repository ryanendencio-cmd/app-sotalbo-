import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Admin1\Downloads\S-Cons System Application\S-Cons System\server\index.js');
  final lines = await file.readAsLines();
  bool inBlock = false;
  for (var line in lines) {
    if (line.contains("app.put('/api/workers/:id/approve'")) {
      inBlock = true;
    }
    if (inBlock) {
      print(line);
      if (line.startsWith('  app.') && !line.contains("app.put('/api/workers/:id/approve'")) {
         break;
      }
    }
  }
}
