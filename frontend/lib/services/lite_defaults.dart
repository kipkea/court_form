import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'thai_helper.dart';

class LiteDefaults {
  static List<Map<String, dynamic>> getPaperSizes() {
    return [
      {
        'id': 1,
        'code': 'A4',
        'name': 'กระดาษ A4 มาตรฐาน (210 × 297 มม.)',
        'category': 'STANDARD',
        'width_mm': 210.0,
        'height_mm': 297.0,
        'default_orientation': 'portrait',
      },
      {
        'id': 2,
        'code': 'A5',
        'name': 'กระดาษ A5 ครึ่งแผ่น (148 × 210 มม.)',
        'category': 'STANDARD',
        'width_mm': 148.0,
        'height_mm': 210.0,
        'default_orientation': 'portrait',
      },
      {
        'id': 3,
        'code': 'ENV_DL',
        'name': 'ซองจดหมายมาตรฐาน DL (220 × 110 มม.)',
        'category': 'ENVELOPE',
        'width_mm': 220.0,
        'height_mm': 110.0,
        'default_orientation': 'landscape',
      },
      {
        'id': 4,
        'code': 'ENV_GOV9X4',
        'name': 'ซองจดหมายราชการ 9×4 นิ้ว (228.6 × 101.6 มม.)',
        'category': 'ENVELOPE',
        'width_mm': 228.6,
        'height_mm': 101.6,
        'default_orientation': 'landscape',
      },
      {
        'id': 5,
        'code': 'ENV_C5',
        'name': 'ซองเอกสารขนาดกลาง C5 (229 × 162 มม.)',
        'category': 'ENVELOPE',
        'width_mm': 229.0,
        'height_mm': 162.0,
        'default_orientation': 'landscape',
      },
      {
        'id': 6,
        'code': 'ENV_C4',
        'name': 'ซองเอกสารขนาดใหญ่ C4 (324 × 229 มม.)',
        'category': 'ENVELOPE',
        'width_mm': 324.0,
        'height_mm': 229.0,
        'default_orientation': 'landscape',
      },
      {
        'id': 7,
        'code': 'CHEQUE_STD',
        'name': 'สมุดเช็คธนาคารมาตรฐาน (178 × 89 มม.)',
        'category': 'CHEQUE',
        'width_mm': 178.0,
        'height_mm': 89.0,
        'default_orientation': 'landscape',
      },
      {
        'id': 8,
        'code': 'CHEQUE_STUB',
        'name': 'สมุดเช็คพร้อมต้นขั้ว (228 × 89 มม.)',
        'category': 'CHEQUE',
        'width_mm': 228.0,
        'height_mm': 89.0,
        'default_orientation': 'landscape',
      },
    ];
  }

  static List<Map<String, dynamic>> getPrinterProfiles() {
    return [
      {
        'id': 1,
        'name': 'เครื่องพิมพ์เลเซอร์มาตรฐาน (ค่าเริ่มต้น 0.0 มม.)',
        'offset_x_mm': 0.0,
        'offset_y_mm': 0.0,
        'is_shared': true,
      },
      {
        'id': 2,
        'name': 'ถาดป้อนซองจดหมาย (ชดเชย X:+1.5, Y:+1.0 มม.)',
        'offset_x_mm': 1.5,
        'offset_y_mm': 1.0,
        'is_shared': true,
      },
      {
        'id': 3,
        'name': 'เครื่องพิมพ์เช็ค / แคร่ป้อนมือ (ชดเชย X:-1.0, Y:+0.5 มม.)',
        'offset_x_mm': -1.0,
        'offset_y_mm': 0.5,
        'is_shared': true,
      },
    ];
  }

  static List<Map<String, dynamic>> getDefaultTemplates() {
    return [
      {
        'id': 1,
        'code': 'cheque_standard',
        'name': 'งานพิมพ์เช็คธนาคาร (มาตรฐานเช็คสั่งจ่าย 178×89 มม.)',
        'category': 'CHEQUE',
        'description': 'พิมพ์ลงใบเช็คธนาคารจริง มีตัวช่วยแปลงจำนวนเงินเป็นตัวอักษรภาษาไทยอัตโนมัติ ขีดคร่อม A/C PAYEE ONLY และช่องวันที่ 8 หลัก',
        'paper_preset': 'CHEQUE_STD',
        'width_mm': 178.0,
        'height_mm': 89.0,
        'orientation': 'landscape',
        'background_image': '',
        'print_background': false,
        'grid_size_mm': 2.0,
        'default_offset_x_mm': 0.0,
        'default_offset_y_mm': 0.0,
        'allowed_data_source': '',
        'fields_schema': [
          {
            'id': 'f_ac_payee',
            'key': 'ac_payee',
            'label': 'ขีดคร่อม A/C PAYEE ONLY',
            'field_type': 'cheque_cross',
            'x_mm': 10.0,
            'y_mm': 22.0,
            'width_mm': 38.0,
            'height_mm': 14.0,
            'font_size': 13.0,
            'font_bold': true,
            'align': 'center',
            'color': '#B71C1C',
            'cross_text': 'A/C PAYEE ONLY',
            'default_value': 'true',
            'printable': true,
          },
          {
            'id': 'f_cheque_date',
            'key': 'cheque_date',
            'label': 'วันที่สั่งจ่าย (8 หลัก ววดดปปปป)',
            'field_type': 'box_group',
            'x_mm': 114.0,
            'y_mm': 11.5,
            'width_mm': 46.4,
            'height_mm': 8.5,
            'font_size': 17.0,
            'font_bold': true,
            'align': 'center',
            'letter_spacing_mm': 5.8,
            'max_boxes': 8,
            'default_value': '28102569',
            'printable': true,
          },
          {
            'id': 'f_payee_name',
            'key': 'payee_name',
            'label': 'สั่งจ่าย (ชื่อผู้รับเงิน / หน่วยงาน)',
            'field_type': 'text',
            'x_mm': 28.0,
            'y_mm': 27.5,
            'width_mm': 115.0,
            'height_mm': 8.0,
            'font_size': 17.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'นางสาวสมหญิง รักความยุติธรรม',
            'printable': true,
          },
          {
            'id': 'f_strike_bearer',
            'key': 'strike_bearer',
            'label': 'ขีดฆ่า "หรือผู้ถือ"',
            'field_type': 'strike_line',
            'x_mm': 148.0,
            'y_mm': 28.0,
            'width_mm': 22.0,
            'height_mm': 6.0,
            'font_size': 14.0,
            'font_bold': true,
            'align': 'center',
            'default_value': 'true',
            'printable': true,
          },
          {
            'id': 'f_amount_num',
            'key': 'amount_num',
            'label': 'จำนวนเงินตัวเลข (บาท)',
            'field_type': 'currency',
            'x_mm': 112.0,
            'y_mm': 54.0,
            'width_mm': 52.0,
            'height_mm': 9.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'right',
            'prefix': '**',
            'suffix': '**',
            'default_value': '15420.00',
            'printable': true,
          },
          {
            'id': 'f_amount_text',
            'key': 'amount_text',
            'label': 'จำนวนเงินตัวอักษร (แปลงอัตโนมัติ)',
            'field_type': 'bahttext',
            'source_field': 'amount_num',
            'wrap_brackets': true,
            'x_mm': 32.0,
            'y_mm': 39.5,
            'width_mm': 132.0,
            'height_mm': 8.0,
            'font_size': 16.5,
            'font_bold': true,
            'align': 'left',
            'default_value': '',
            'printable': true,
          },
        ],
      },
      {
        'id': 2,
        'code': 'cheque_with_stub',
        'name': 'งานพิมพ์เช็คพร้อมต้นขั้ว (228×89 มม.)',
        'category': 'CHEQUE',
        'description': 'สำหรับสมุดเช็คที่มีต้นขั้วด้านซ้าย พิมพ์รายละเอียดลงทั้งต้นขั้วและตัวเช็คพร้อมกัน',
        'paper_preset': 'CHEQUE_STUB',
        'width_mm': 228.0,
        'height_mm': 89.0,
        'orientation': 'landscape',
        'background_image': '',
        'print_background': false,
        'grid_size_mm': 2.0,
        'default_offset_x_mm': 0.0,
        'default_offset_y_mm': 0.0,
        'allowed_data_source': '',
        'fields_schema': [
          {
            'id': 's_stub_date',
            'key': 'stub_date',
            'label': '[ต้นขั้ว] วันที่',
            'field_type': 'date_thai',
            'date_format': 'short',
            'x_mm': 6.0,
            'y_mm': 12.0,
            'width_mm': 40.0,
            'height_mm': 7.0,
            'font_size': 14.0,
            'font_bold': false,
            'align': 'left',
            'default_value': '2026-10-28',
            'printable': true,
          },
          {
            'id': 's_stub_payee',
            'key': 'payee_name',
            'label': '[ต้นขั้ว] ชื่อผู้รับเงิน',
            'field_type': 'text',
            'x_mm': 6.0,
            'y_mm': 24.0,
            'width_mm': 42.0,
            'height_mm': 8.0,
            'font_size': 14.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'นายสมชาย ใจดี',
            'printable': true,
          },
          {
            'id': 's_stub_memo',
            'key': 'stub_memo',
            'label': '[ต้นขั้ว] รายการ/อ้างอิงฎีกา',
            'field_type': 'multiline',
            'x_mm': 6.0,
            'y_mm': 36.0,
            'width_mm': 42.0,
            'height_mm': 16.0,
            'font_size': 13.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'ค่าตอบแทนปฏิบัติงานนอกเวลา',
            'printable': true,
          },
          {
            'id': 's_stub_amount',
            'key': 'amount_num',
            'label': 'จำนวนเงิน (บาท)',
            'field_type': 'currency',
            'x_mm': 6.0,
            'y_mm': 58.0,
            'width_mm': 40.0,
            'height_mm': 8.0,
            'font_size': 15.0,
            'font_bold': true,
            'align': 'right',
            'default_value': '8500.00',
            'printable': true,
          },
          {
            'id': 's_cheque_date',
            'key': 'cheque_date',
            'label': '[ตัวเช็ค] วันที่ 8 หลัก',
            'field_type': 'box_group',
            'x_mm': 164.0,
            'y_mm': 11.5,
            'width_mm': 46.4,
            'height_mm': 8.5,
            'font_size': 17.0,
            'font_bold': true,
            'align': 'center',
            'letter_spacing_mm': 5.8,
            'max_boxes': 8,
            'default_value': '28102569',
            'printable': true,
          },
          {
            'id': 's_cheque_payee',
            'key': 'cheque_payee_copy',
            'label': '[ตัวเช็ค] สั่งจ่ายชื่อผู้รับเงิน',
            'field_type': 'text',
            'x_mm': 78.0,
            'y_mm': 27.5,
            'width_mm': 115.0,
            'height_mm': 8.0,
            'font_size': 17.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'นายสมชาย ใจดี',
            'printable': true,
          },
          {
            'id': 's_cheque_bahttext',
            'key': 'amount_text',
            'label': '[ตัวเช็ค] จำนวนเงินตัวอักษร',
            'field_type': 'bahttext',
            'source_field': 'amount_num',
            'wrap_brackets': true,
            'x_mm': 82.0,
            'y_mm': 39.5,
            'width_mm': 132.0,
            'height_mm': 8.0,
            'font_size': 16.5,
            'font_bold': true,
            'align': 'left',
            'default_value': '',
            'printable': true,
          },
          {
            'id': 's_cheque_amount_box',
            'key': 'cheque_amount_box',
            'label': '[ตัวเช็ค] จำนวนเงินตัวเลขในกรอบ',
            'field_type': 'currency',
            'x_mm': 162.0,
            'y_mm': 54.0,
            'width_mm': 52.0,
            'height_mm': 9.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'right',
            'prefix': '**',
            'suffix': '**',
            'default_value': '8500.00',
            'printable': true,
          },
        ],
      },
      {
        'id': 3,
        'code': 'envelope_dl_official',
        'name': 'งานจ่าหน้าซองจดหมายราชการ (ซอง DL มาตรฐาน 220×110 มม.)',
        'category': 'ENVELOPE',
        'description': 'สำหรับจ่าหน้าซองจดหมายราชการ พร้อมลงช่องรหัสไปรษณีย์ 5 หลักแยกช่องอัตโนมัติ',
        'paper_preset': 'ENV_DL',
        'width_mm': 220.0,
        'height_mm': 110.0,
        'orientation': 'landscape',
        'background_image': '',
        'print_background': false,
        'grid_size_mm': 5.0,
        'default_offset_x_mm': 0.0,
        'default_offset_y_mm': 0.0,
        'allowed_data_source': '',
        'fields_schema': [
          {
            'id': 'e_sender_org',
            'key': 'sender_org',
            'label': 'ชื่อหน่วยงานผู้ส่ง (มุมซ้ายบน)',
            'field_type': 'text',
            'x_mm': 14.0,
            'y_mm': 12.0,
            'width_mm': 90.0,
            'height_mm': 7.0,
            'font_size': 15.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'ศาลแขวงเชียงดาว จังหวัดเชียงใหม่',
            'printable': true,
          },
          {
            'id': 'e_doc_no',
            'key': 'doc_no',
            'label': 'ที่หนังสือส่ง (ศย ...)',
            'field_type': 'text',
            'x_mm': 14.0,
            'y_mm': 20.0,
            'width_mm': 85.0,
            'height_mm': 7.0,
            'font_size': 14.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'ที่ ศย 305.028/',
            'printable': true,
          },
          {
            'id': 'e_prefix',
            'key': 'recipient_prefix',
            'label': 'คำขึ้นต้นผู้รับ (เช่น เรียน)',
            'field_type': 'text',
            'x_mm': 62.0,
            'y_mm': 42.0,
            'width_mm': 25.0,
            'height_mm': 8.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'เรียน',
            'printable': true,
          },
          {
            'id': 'e_recipient_name',
            'key': 'recipient_name',
            'label': 'ชื่อผู้รับ / ตำแหน่ง / หน่วยงานปลายทาง',
            'field_type': 'text',
            'x_mm': 78.0,
            'y_mm': 42.0,
            'width_mm': 125.0,
            'height_mm': 8.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'ผู้อำนวยการสำนักอำนวยการประจำศาลจังหวัดเชียงใหม่',
            'printable': true,
          },
          {
            'id': 'e_addr_line1',
            'key': 'address_line1',
            'label': 'ที่อยู่บรรทัดที่ 1 (เลขที่/ถนน/ตำบล)',
            'field_type': 'text',
            'x_mm': 78.0,
            'y_mm': 53.0,
            'width_mm': 128.0,
            'height_mm': 8.0,
            'font_size': 16.5,
            'font_bold': false,
            'align': 'left',
            'default_value': 'ถนนโชตนา ตำบลช้างเผือก',
            'printable': true,
          },
          {
            'id': 'e_addr_line2',
            'key': 'address_line2',
            'label': 'ที่อยู่บรรทัดที่ 2 (อำเภอ/จังหวัด)',
            'field_type': 'text',
            'x_mm': 78.0,
            'y_mm': 64.0,
            'width_mm': 128.0,
            'height_mm': 8.0,
            'font_size': 16.5,
            'font_bold': false,
            'align': 'left',
            'default_value': 'อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่',
            'printable': true,
          },
          {
            'id': 'e_postal_code',
            'key': 'postal_code',
            'label': 'รหัสไปรษณีย์ (5 หลักแยกช่อง)',
            'field_type': 'box_group',
            'x_mm': 140.0,
            'y_mm': 87.5,
            'width_mm': 32.5,
            'height_mm': 9.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'center',
            'letter_spacing_mm': 6.5,
            'max_boxes': 5,
            'default_value': '50300',
            'printable': true,
          },
        ],
      },
      {
        'id': 4,
        'code': 'envelope_c5_document',
        'name': 'งานจ่าหน้าซองเอกสารขนาดกลาง (ซอง C5 229×162 มม.)',
        'category': 'ENVELOPE',
        'description': 'สำหรับส่งเอกสารราชการหรือสำนวนคดีขนาดซอง C5',
        'paper_preset': 'ENV_C5',
        'width_mm': 229.0,
        'height_mm': 162.0,
        'orientation': 'landscape',
        'background_image': '',
        'print_background': false,
        'grid_size_mm': 5.0,
        'default_offset_x_mm': 0.0,
        'default_offset_y_mm': 0.0,
        'allowed_data_source': '',
        'fields_schema': [
          {
            'id': 'c5_sender',
            'key': 'sender_org',
            'label': 'หน่วยงานผู้ส่ง',
            'field_type': 'multiline',
            'x_mm': 16.0,
            'y_mm': 14.0,
            'width_mm': 95.0,
            'height_mm': 18.0,
            'font_size': 15.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'ศาลแขวงเชียงดาว\nอำเภอเชียงดาว จังหวัดเชียงใหม่ 50170',
            'printable': true,
          },
          {
            'id': 'c5_service_type',
            'key': 'service_type',
            'label': 'ประเภทการส่ง (เช่น ด่วนที่สุด / ลงทะเบียน)',
            'field_type': 'text',
            'x_mm': 16.0,
            'y_mm': 38.0,
            'width_mm': 65.0,
            'height_mm': 9.0,
            'font_size': 18.0,
            'font_bold': true,
            'align': 'center',
            'color': '#C62828',
            'draw_border': true,
            'default_value': 'ด่วนที่สุด / ลงทะเบียน',
            'printable': true,
          },
          {
            'id': 'c5_recipient',
            'key': 'recipient_name',
            'label': 'ชื่อผู้รับ / หน่วยงาน',
            'field_type': 'text',
            'x_mm': 70.0,
            'y_mm': 68.0,
            'width_mm': 140.0,
            'height_mm': 10.0,
            'font_size': 20.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'เรียน ผู้อำนวยการสำนักอำนวยการประจำศาลแขวงเชียงดาว',
            'printable': true,
          },
          {
            'id': 'c5_full_addr',
            'key': 'full_address',
            'label': 'ที่อยู่ผู้รับ',
            'field_type': 'multiline',
            'x_mm': 70.0,
            'y_mm': 82.0,
            'width_mm': 140.0,
            'height_mm': 25.0,
            'font_size': 18.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'เลขที่ 399 หมู่ที่ 6 ตำบลเชียงดาว อำเภอเชียงดาว จังหวัดเชียงใหม่',
            'printable': true,
          },
          {
            'id': 'c5_postal',
            'key': 'postal_code',
            'label': 'รหัสไปรษณีย์',
            'field_type': 'text',
            'x_mm': 130.0,
            'y_mm': 125.0,
            'width_mm': 60.0,
            'height_mm': 10.0,
            'font_size': 22.0,
            'font_bold': true,
            'align': 'left',
            'default_value': '50170',
            'printable': true,
          },
        ],
      },
      {
        'id': 5,
        'code': 'survey_satisfaction_a4',
        'name': 'แบบสอบถามประเมินความพึงพอใจผู้มาติดต่อราชการศาล (A4)',
        'category': 'SURVEY',
        'description': 'แบบฟอร์มขนาด A4 มาตรฐาน พร้อมหัวแบบสอบถาม ช่องกรอกข้อมูลผู้ติดต่อ ช่องติ๊กเครื่องหมาย ✓ และข้อเสนอแนะ',
        'paper_preset': 'A4',
        'width_mm': 210.0,
        'height_mm': 297.0,
        'orientation': 'portrait',
        'background_image': '',
        'print_background': true,
        'grid_size_mm': 5.0,
        'default_offset_x_mm': 0.0,
        'default_offset_y_mm': 0.0,
        'allowed_data_source': '',
        'fields_schema': [
          {
            'id': 'sv_header',
            'key': 'static_header',
            'label': '[หัวกระดาษ] ชื่อแบบสอบถาม',
            'field_type': 'static_text',
            'x_mm': 20.0,
            'y_mm': 20.0,
            'width_mm': 170.0,
            'height_mm': 10.0,
            'font_size': 20.0,
            'font_bold': true,
            'align': 'center',
            'default_value': 'แบบสอบถามความพึงพอใจของผู้มาติดต่อราชการ ศาลแขวงเชียงดาว',
            'printable': true,
          },
          {
            'id': 'sv_date',
            'key': 'survey_date',
            'label': 'วันที่ทำแบบสอบถาม',
            'field_type': 'date_thai',
            'date_format': 'official',
            'x_mm': 115.0,
            'y_mm': 34.0,
            'width_mm': 75.0,
            'height_mm': 8.0,
            'font_size': 16.0,
            'font_bold': false,
            'align': 'right',
            'default_value': '2026-10-28',
            'printable': true,
          },
          {
            'id': 'sv_respondent',
            'key': 'respondent_name',
            'label': 'ชื่อ-นามสกุล ผู้ประเมิน / ผู้รับบริการ',
            'field_type': 'text',
            'x_mm': 25.0,
            'y_mm': 48.0,
            'width_mm': 105.0,
            'height_mm': 8.0,
            'font_size': 16.0,
            'font_bold': true,
            'align': 'left',
            'default_value': 'นายอภิชาติ กันสีนวล',
            'printable': true,
          },
          {
            'id': 'sv_dept',
            'key': 'respondent_dept',
            'label': 'หน่วยงาน / ตำแหน่ง',
            'field_type': 'text',
            'x_mm': 132.0,
            'y_mm': 48.0,
            'width_mm': 58.0,
            'height_mm': 8.0,
            'font_size': 16.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'ประชาชนผู้มาติดต่อราชการ',
            'printable': true,
          },
          {
            'id': 'sv_service_topic',
            'key': 'service_topic',
            'label': 'เรื่องที่มาติดต่อราชการ',
            'field_type': 'text',
            'x_mm': 25.0,
            'y_mm': 62.0,
            'width_mm': 165.0,
            'height_mm': 8.0,
            'font_size': 16.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'ยื่นคำร้อง / ขอคัดถ่ายเอกสารสำนวนคดี / ติดต่อส่วนบริการประชาชน',
            'printable': true,
          },
          {
            'id': 'sv_chk_excellent',
            'key': 'rate_excellent',
            'label': 'ติ๊ก ✓ ระดับความพึงพอใจ: ดีมากที่สุด (5)',
            'field_type': 'checkbox',
            'draw_box': true,
            'x_mm': 25.0,
            'y_mm': 80.0,
            'width_mm': 6.0,
            'height_mm': 6.0,
            'font_size': 16.0,
            'font_bold': true,
            'default_value': 'true',
            'printable': true,
          },
          {
            'id': 'sv_lbl_excellent',
            'key': 'lbl_excellent',
            'label': '[ข้อความ] ดีมากที่สุด (5 คะแนน)',
            'field_type': 'static_text',
            'x_mm': 34.0,
            'y_mm': 79.5,
            'width_mm': 65.0,
            'height_mm': 8.0,
            'font_size': 16.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'พึงพอใจในระดับดีมากที่สุด (5 คะแนน)',
            'printable': true,
          },
          {
            'id': 'sv_comment',
            'key': 'comment_text',
            'label': 'ข้อเสนอแนะเพิ่มเติม',
            'field_type': 'multiline',
            'draw_border': true,
            'x_mm': 25.0,
            'y_mm': 98.0,
            'width_mm': 165.0,
            'height_mm': 35.0,
            'font_size': 16.0,
            'font_bold': false,
            'align': 'left',
            'default_value': 'เจ้าหน้าที่ให้บริการด้วยความสุภาพ รวดเร็ว และให้คำแนะนำชัดเจนดีมาก',
            'printable': true,
          },
        ],
      },
    ];
  }

  /// แปลงไฟล์ CSV ในโหมด Lite/Standalone โดยไม่ต้องใช้ Server
  static Map<String, dynamic> parseCsvLocally(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return {'columns': <String>[], 'rows': <Map<String, dynamic>>[]};

    List<String> splitCsvLine(String line) {
      final result = <String>[];
      final sb = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          inQuotes = !inQuotes;
        } else if (ch == ',' && !inQuotes) {
          result.add(sb.toString().trim());
          sb.clear();
        } else {
          sb.write(ch);
        }
      }
      result.add(sb.toString().trim());
      return result;
    }

    final headers = splitCsvLine(lines.first);
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = splitCsvLine(lines[i]);
      final map = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        map[headers[c]] = c < cols.length ? cols[c] : '';
      }
      rows.add(map);
    }
    return {'columns': headers, 'rows': rows};
  }

  static String _resolveFieldText(Map<String, dynamic> field, Map<String, String> values) {
    final key = (field['key'] ?? '').toString();
    final ftype = (field['field_type'] ?? 'text').toString();
    final rawVal = values[key] ?? (field['default_value'] ?? '').toString();

    if (ftype == 'bahttext') {
      final srcKey = (field['source_field'] ?? '').toString();
      final wrap = field['wrap_brackets'] == true;
      if (srcKey.isNotEmpty && (values[srcKey] ?? '').isNotEmpty) {
        return ThaiHelper.numberToBahtText(values[srcKey]!, wrapBrackets: wrap);
      }
      return ThaiHelper.numberToBahtText(rawVal, wrapBrackets: wrap);
    }
    if (ftype == 'currency') {
      return ThaiHelper.formatCurrency(
        rawVal,
        prefix: (field['prefix'] ?? '').toString(),
        suffix: (field['suffix'] ?? '').toString(),
      );
    }
    if (ftype == 'date_thai') {
      return ThaiHelper.formatThaiDate(
        rawVal,
        format: (field['date_format'] ?? 'full').toString(),
        thaiDigits: field['thai_digits'] == true,
      );
    }
    if (field['thai_digits'] == true) {
      return ThaiHelper.toThaiDigits(rawVal);
    }
    return rawVal;
  }

  static Color _parseHex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return Colors.black;
    try {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  /// วาดหน้าแบบพิมพ์ด้วย Flutter Canvas ความละเอียดสูง (สำหรับโหมด Lite Standalone)
  static Future<ui.Image> renderPageAsUiImage({
    required double widthMm,
    required double heightMm,
    required List<Map<String, dynamic>> fieldsSchema,
    required Map<String, String> values,
    required String backgroundImageBase64,
    required bool printBackground,
    required double offsetXMm,
    required double offsetYMm,
    double dpi = 240.0,
  }) async {
    final pxPerMm = dpi / 25.4;
    final wPx = (widthMm * pxPerMm).round();
    final hPx = (heightMm * pxPerMm).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, wPx.toDouble(), hPx.toDouble()));

    // พื้นหลังสีขาว
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wPx.toDouble(), hPx.toDouble()),
      Paint()..color = Colors.white,
    );

    // วาดภาพพื้นหลังถ้าเปิด printBackground
    if (printBackground && backgroundImageBase64.isNotEmpty) {
      try {
        final clean = backgroundImageBase64.contains(',')
            ? backgroundImageBase64.split(',').last
            : backgroundImageBase64;
        final imgBytes = base64Decode(clean);
        final codec = await ui.instantiateImageCodec(imgBytes);
        final frame = await codec.getNextFrame();
        canvas.drawImageRect(
          frame.image,
          Rect.fromLTWH(0, 0, frame.image.width.toDouble(), frame.image.height.toDouble()),
          Rect.fromLTWH(
            offsetXMm * pxPerMm,
            offsetYMm * pxPerMm,
            wPx.toDouble(),
            hPx.toDouble(),
          ),
          Paint(),
        );
      } catch (_) {}
    }

    for (final field in fieldsSchema) {
      if (field['printable'] == false) continue;

      final ftype = (field['field_type'] ?? 'text').toString();
      final fxPx = (((field['x_mm'] as num?)?.toDouble() ?? 0.0) + offsetXMm) * pxPerMm;
      final fyPx = (((field['y_mm'] as num?)?.toDouble() ?? 0.0) + offsetYMm) * pxPerMm;
      final fwPx = ((field['width_mm'] as num?)?.toDouble() ?? 60.0) * pxPerMm;
      final fhPx = ((field['height_mm'] as num?)?.toDouble() ?? 8.5) * pxPerMm;
      final fontSizePt = (field['font_size'] as num?)?.toDouble() ?? 16.0;
      final fontPx = fontSizePt * 0.3528 * pxPerMm;
      final isBold = field['font_bold'] == true;
      final alignStr = (field['align'] ?? 'left').toString();
      final color = _parseHex(field['color']?.toString());
      final key = (field['key'] ?? '').toString();
      final rawVal = values[key] ?? (field['default_value'] ?? '').toString();

      if (ftype == 'cheque_cross') {
        final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
        if (isChecked) {
          canvas.save();
          canvas.translate(fxPx, fyPx);
          canvas.rotate(-0.54);
          final linePaint = Paint()
            ..color = const Color(0xFFB71C1C)
            ..strokeWidth = 0.45 * pxPerMm;
          canvas.drawLine(Offset.zero, Offset(38 * pxPerMm, 0), linePaint);
          canvas.drawLine(Offset(0, 6.5 * pxPerMm), Offset(38 * pxPerMm, 6.5 * pxPerMm), linePaint);
          final tp = TextPainter(
            text: TextSpan(
              text: (field['cross_text'] ?? 'A/C PAYEE ONLY').toString(),
              style: TextStyle(
                fontFamily: 'THSarabunNew',
                fontSize: fontPx * 0.85,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFB71C1C),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 38 * pxPerMm);
          tp.paint(canvas, Offset((38 * pxPerMm - tp.width) / 2, 1.0 * pxPerMm));
          canvas.restore();
        }
        continue;
      }

      if (ftype == 'strike_line') {
        final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
        if (isChecked) {
          canvas.drawLine(
            Offset(fxPx, fyPx + fhPx / 2),
            Offset(fxPx + fwPx, fyPx + fhPx / 2),
            Paint()
              ..color = color
              ..strokeWidth = 0.55 * pxPerMm,
          );
        }
        continue;
      }

      if (ftype == 'checkbox') {
        final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
        final boxSz = math.min(fwPx, fhPx);
        if (field['draw_box'] == true) {
          canvas.drawRect(
            Rect.fromLTWH(fxPx, fyPx, boxSz, boxSz),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.3 * pxPerMm,
          );
        }
        if (isChecked) {
          final p = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6 * pxPerMm;
          final path = Path()
            ..moveTo(fxPx + boxSz * 0.18, fyPx + boxSz * 0.52)
            ..lineTo(fxPx + boxSz * 0.42, fyPx + boxSz * 0.80)
            ..lineTo(fxPx + boxSz * 0.86, fyPx + boxSz * 0.16);
          canvas.drawPath(path, p);
        }
        continue;
      }

      final displayText = _resolveFieldText(field, values);
      if (displayText.isEmpty) continue;

      if (ftype == 'box_group') {
        final spacingMm = (field['letter_spacing_mm'] as num?)?.toDouble() ?? 5.8;
        final spacingPx = spacingMm * pxPerMm;
        final chars = displayText.replaceAll(' ', '').split('');
        final maxBoxes = (field['max_boxes'] as num?)?.toInt() ?? chars.length;
        for (int i = 0; i < math.min(chars.length, maxBoxes); i++) {
          final tp = TextPainter(
            text: TextSpan(
              text: chars[i],
              style: TextStyle(
                fontFamily: 'THSarabunNew',
                fontSize: fontPx,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
                height: 1.0,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final cx = fxPx + (i * spacingPx) + (spacingPx - tp.width) / 2;
          tp.paint(canvas, Offset(cx, fyPx));
        }
        continue;
      }

      TextAlign textAlign = TextAlign.left;
      if (alignStr == 'center') textAlign = TextAlign.center;
      if (alignStr == 'right') textAlign = TextAlign.right;

      final tp = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            fontFamily: 'THSarabunNew',
            fontSize: fontPx,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
            height: 1.08,
          ),
        ),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: fwPx, maxWidth: fwPx);

      tp.paint(canvas, Offset(fxPx, fyPx));

      if (field['draw_border'] == true) {
        canvas.drawRect(
          Rect.fromLTWH(fxPx, fyPx, fwPx, fhPx),
          Paint()
            ..color = Colors.black54
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.25 * pxPerMm,
        );
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(wPx, hPx);
  }

  /// เรนเดอร์ PNG 300 DPI สำหรับโหมด Lite Standalone
  static Future<Uint8List> renderLocalPngBytes({
    required double widthMm,
    required double heightMm,
    required List<Map<String, dynamic>> fieldsSchema,
    required Map<String, String> values,
    required String backgroundImageBase64,
    required bool printBackground,
    required double offsetXMm,
    required double offsetYMm,
  }) async {
    final img = await renderPageAsUiImage(
      widthMm: widthMm,
      heightMm: heightMm,
      fieldsSchema: fieldsSchema,
      values: values,
      backgroundImageBase64: backgroundImageBase64,
      printBackground: printBackground,
      offsetXMm: offsetXMm,
      offsetYMm: offsetYMm,
      dpi: 300.0,
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
