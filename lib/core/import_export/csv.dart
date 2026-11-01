/// RFC 4180 CSV parsing / writing (quoted fields, embedded commas, quotes
/// and newlines, CRLF or LF line endings, optional UTF-8 BOM).
class Csv {
  Csv._();

  static List<List<String>> parse(String input) {
    var text = input;
    if (text.startsWith('﻿')) text = text.substring(1);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var i = 0;
    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
      row = <String>[];
    }

    while (i < text.length) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\r') {
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else if (c == '\n') {
        endRow();
      } else {
        field.write(c);
      }
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static String encodeRow(List<String> fields) => fields.map((f) {
        if (f.contains(RegExp(r'[",\r\n]')) || f.startsWith(' ') ||
            f.endsWith(' ')) {
          return '"${f.replaceAll('"', '""')}"';
        }
        return f;
      }).join(',');

  static String encode(List<List<String>> rows) =>
      '${rows.map(encodeRow).join('\r\n')}\r\n';
}
