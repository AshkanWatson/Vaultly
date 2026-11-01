import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/import_export/csv.dart';
import 'package:vaultly/core/import_export/csv_importer.dart';

void main() {
  test('parses quoted fields with commas, quotes and newlines', () {
    final rows = Csv.parse('a,"b,c","say ""hi""","multi\nline"\r\nx,y,z,w\n');
    expect(rows, [
      ['a', 'b,c', 'say "hi"', 'multi\nline'],
      ['x', 'y', 'z', 'w'],
    ]);
  });

  test('imports Apple Passwords export', () {
    final r = CsvImporter.parse(
        'Title,URL,Username,Password,Notes,OTPAuth\n'
        'GitHub,https://github.com/,octo,"pa,ss",note,otpauth://totp/x?secret=JBSWY3DPEHPK3PXP\n');
    expect(r.source, 'Apple Passwords');
    final i = r.items.single;
    expect(i.title, 'GitHub');
    expect(i.password, 'pa,ss');
    expect(i.hasOtp, isTrue);
  });

  test('imports Chrome, LastPass and Bitwarden exports', () {
    expect(
        CsvImporter.parse('name,url,username,password,note\n'
                ',https://www.example.com/,u,p,\n')
            .items
            .single
            .displayTitle,
        'example.com');
    final lp = CsvImporter.parse(
        'url,username,password,totp,extra,name,grouping,fav\n'
        'https://a.com,u,p,,,A,,1\n'
        'http://sn,,,,secret note body,Note,,0\n');
    expect(lp.source, 'LastPass');
    expect(lp.items.first.favorite, isTrue);
    expect(lp.items.last.notes, 'secret note body');
    final bw = CsvImporter.parse(
        'folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp\n'
        ',,login,Site,,,0,https://site.com,me,pw,\n');
    expect(bw.source, 'Bitwarden');
    expect(bw.items.single.username, 'me');
  });

  test('export → import round-trip', () {
    final items = CsvImporter.parse('Title,URL,Username,Password,Notes,OTPAuth\n'
            'T,https://t.com,u,"we""ird, pw","multi\nline note",\n')
        .items;
    final again = CsvImporter.parse(CsvImporter.export(items)).items.single;
    expect(again.password, 'we"ird, pw');
    expect(again.notes, 'multi\nline note');
  });

  test('rejects CSVs without credential columns', () {
    expect(() => CsvImporter.parse('a,b\n1,2\n'), throwsFormatException);
  });
}
