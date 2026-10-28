class ThaiHelper {
  static const List<String> _numText = [
    'ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'
  ];
  static const List<String> _unitText = [
    '', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน'
  ];
  static const List<String> _monthsFull = [
    '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];
  static const List<String> _monthsShort = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];

  static String _convertChunk(String s) {
    final trimmed = s.replaceFirst(RegExp(r'^0+'), '');
    if (trimmed.isEmpty) return '';
    final len = trimmed.length;
    final sb = StringBuffer();
    for (int i = 0; i < len; i++) {
      final d = int.tryParse(trimmed[i]) ?? 0;
      final pos = len - i - 1;
      if (d == 0) continue;
      if (pos == 1 && d == 1) {
        sb.write('สิบ');
      } else if (pos == 1 && d == 2) {
        sb.write('ยี่สิบ');
      } else if (pos == 0 && d == 1 && len > 1) {
        sb.write('เอ็ด');
      } else {
        sb.write(_numText[d] + _unitText[pos]);
      }
    }
    return sb.toString();
  }

  static String _convertInt(int n) {
    if (n == 0) return 'ศูนย์';
    String s = n.toString();
    final chunks = <String>[];
    while (s.isNotEmpty) {
      final start = s.length > 6 ? s.length - 6 : 0;
      chunks.add(s.substring(start));
      s = s.substring(0, start);
    }
    final sb = StringBuffer();
    for (int i = chunks.length - 1; i >= 0; i--) {
      final cText = _convertChunk(chunks[i]);
      if (cText.isNotEmpty) {
        sb.write(cText);
        if (i > 0) sb.write('ล้าน');
      } else if (i > 0 && sb.isNotEmpty) {
        sb.write('ล้าน');
      }
    }
    return sb.toString();
  }

  static String numberToBahtText(String raw, {bool wrapBrackets = true}) {
    final cleaned = raw.replaceAll(',', '').replaceAll('฿', '').replaceAll('บาท', '').trim();
    if (cleaned.isEmpty) return '';
    final val = double.tryParse(cleaned);
    if (val == null) return raw;

    final isNeg = val < 0;
    final absVal = val.abs();
    final intPart = absVal.floor();
    final satang = ((absVal - intPart) * 100).round();

    String text = '';
    if (intPart == 0 && satang == 0) {
      text = 'ศูนย์บาทถ้วน';
    } else {
      if (isNeg) text += 'ลบ';
      if (intPart > 0) text += '${_convertInt(intPart)}บาท';
      if (satang > 0) {
        text += '${_convertInt(satang)}สตางค์';
      } else {
        text += 'ถ้วน';
      }
    }
    return wrapBrackets ? '(-$text-)' : text;
  }

  static String formatCurrency(String raw, {String prefix = '', String suffix = ''}) {
    final cleaned = raw.replaceAll(',', '').replaceAll('฿', '').trim();
    if (cleaned.isEmpty) return '';
    final val = double.tryParse(cleaned);
    if (val == null) return raw;
    final parts = val.toStringAsFixed(2).split('.');
    final intStr = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$prefix$intStr.${parts[1]}$suffix';
  }

  static String toThaiDigits(String s) {
    const eng = '0123456789';
    const th = '๐๑๒๓๔๕๖๗๘๙';
    String out = s;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(eng[i], th[i]);
    }
    return out;
  }

  static String formatThaiDate(String raw, {String format = 'full', bool thaiDigits = false}) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    DateTime? dt = DateTime.tryParse(s);
    if (dt == null && s.contains('/')) {
      final p = s.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]) ?? 1;
        final m = int.tryParse(p[1]) ?? 1;
        int y = int.tryParse(p[2]) ?? 2026;
        if (y > 2400) y -= 543;
        dt = DateTime(y, m, d);
      }
    }
    if (dt == null) return thaiDigits ? toThaiDigits(s) : s;

    final yearBe = dt.year < 2400 ? dt.year + 543 : dt.year;
    final day = dt.day;
    final month = dt.month;
    String res;
    if (format == 'short') {
      res = '$day ${_monthsShort[month]} $yearBe';
    } else if (format == 'official') {
      res = 'วันที่ $day เดือน ${_monthsFull[month]} พ.ศ. $yearBe';
    } else if (format == 'slash') {
      res = '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$yearBe';
    } else if (format == 'digits8') {
      res = '${day.toString().padLeft(2, '0')}${month.toString().padLeft(2, '0')}$yearBe';
    } else {
      res = '$day ${_monthsFull[month]} $yearBe';
    }
    return thaiDigits ? toThaiDigits(res) : res;
  }
}
