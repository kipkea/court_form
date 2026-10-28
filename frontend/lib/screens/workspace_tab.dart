import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import '../widgets/datasource_picker_dialog.dart';
import '../widgets/live_paper_canvas.dart';

class WorkspaceTab extends StatefulWidget {
  final VoidCallback onSwitchToBatchTab;
  const WorkspaceTab({super.key, required this.onSwitchToBatchTab});

  @override
  State<WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<WorkspaceTab> {
  String _categoryFilter = 'ALL';

  Future<void> _pickBackgroundImage(FormProvider prov) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (files.isNotEmpty) {
      final f = files.first;
      final bytes = await f.readAsBytes();
      final ext = (f.extension ?? 'png').toLowerCase();
      final mime = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';
      final b64 = 'data:$mime;base64,${base64Encode(bytes)}';
      prov.setBackgroundImageBase64(b64);
    }
  }

  Future<void> _showSaveTemplateDialog(FormProvider prov, {required bool createNew}) async {
    final tpl = prov.selectedTemplate;
    final nameCtrl = TextEditingController(
      text: createNew
          ? '${tpl?['name'] ?? 'งานประจำใหม่'} (แบบใหม่)'
          : (tpl?['name'] ?? 'งานประจำใหม่').toString(),
    );
    final descCtrl = TextEditingController(text: (tpl?['description'] ?? '').toString());
    String cat = (tpl?['category'] ?? 'CUSTOM').toString();
    String allowedDs = (tpl?['allowed_data_source'] ?? 'portal_users').toString();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(
              createNew ? 'บันทึกเป็นแม่แบบงานประจำใหม่ (Admin)' : 'บันทึกการแก้ไขแม่แบบงานประจำ (Admin)',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'ชื่องานประจำ / แม่แบบ',
                      labelStyle: GoogleFonts.sarabun(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: InputDecoration(
                      labelText: 'หมวดหมู่งานประจำ',
                      labelStyle: GoogleFonts.sarabun(),
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CHEQUE', child: Text('สมุดเช็ค / การเงิน')),
                      DropdownMenuItem(value: 'ENVELOPE', child: Text('ซองจดหมาย / งานสารบรรณ')),
                      DropdownMenuItem(value: 'SURVEY', child: Text('แบบสอบถาม / แบบฟอร์ม A4-A5')),
                      DropdownMenuItem(value: 'OFFICIAL', child: Text('เอกสารราชการ / ใบสำคัญ')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('งานพิมพ์ทั่วไปกำหนดเอง')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => cat = v);
                    },
                  ),
                  if (!prov.isLiteMode) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: allowedDs,
                      decoration: InputDecoration(
                        labelText: 'แหล่งข้อมูลเริ่มต้นที่ผูกกับแม่แบบนี้',
                        labelStyle: GoogleFonts.sarabun(),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'portal_users', child: Text('ข้อมูลบุคลากรและผู้ใช้งานในระบบ')),
                        DropdownMenuItem(value: 'courts', child: Text('ข้อมูลศาลและที่อยู่หน่วยงานมาตรฐาน')),
                        DropdownMenuItem(value: '', child: Text('ไม่ผูกแหล่งข้อมูลเริ่มต้น')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => allowedDs = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'คำอธิบายการใช้งาน',
                      labelStyle: GoogleFonts.sarabun(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('ยกเลิก', style: GoogleFonts.sarabun()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await prov.saveCurrentTemplateAsAdmin(
                    name: nameCtrl.text.trim(),
                    category: cat,
                    description: descCtrl.text.trim(),
                    allowedDataSource: allowedDs,
                    createNew: createNew,
                  );
                  navigator.pop();
                  if (ok) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('บันทึกแม่แบบงานประจำเรียบร้อยแล้ว', style: GoogleFonts.sarabun()),
                        backgroundColor: Colors.teal.shade700,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: Text('บันทึกแม่แบบ', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final filteredTemplates = _categoryFilter == 'ALL'
        ? prov.templates
        : prov.templates.where((t) => t['category'] == _categoryFilter).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // =====================================================================
        // LEFT PANEL: Template Selection, Form Inputs & Printer Offset
        // =====================================================================
        Container(
          width: 390,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // 1. Routine Template Selector Card
              Container(
                padding: const EdgeInsets.all(14),
                color: const Color(0xFFF4F7F6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_special_rounded, color: Color(0xFF00695C), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'เลือกงานประจำ (Routine Template)',
                          style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCatChip('ALL', 'ทั้งหมด'),
                          _buildCatChip('CHEQUE', 'สมุดเช็ค'),
                          _buildCatChip('ENVELOPE', 'ซองจดหมาย'),
                          _buildCatChip('SURVEY', 'แบบสอบถาม A4'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: filteredTemplates.any((t) => t['id'] == prov.selectedTemplate?['id'])
                          ? (prov.selectedTemplate?['id'] as int?)
                          : (filteredTemplates.isNotEmpty ? (filteredTemplates.first['id'] as int?) : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: filteredTemplates.map((t) {
                        return DropdownMenuItem<int>(
                          value: t['id'] as int,
                          child: Text(
                            t['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sarabun(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          final found = prov.templates.firstWhere((t) => t['id'] == id);
                          prov.selectTemplate(found);
                        }
                      },
                    ),
                    if (!prov.isLiteMode) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => DataSourcePickerDialog(
                                    initialSourceCode: prov.selectedTemplate?['allowed_data_source']?.toString(),
                                    onSwitchToBatchTab: widget.onSwitchToBatchTab,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.storage_rounded, size: 17),
                              label: Text(
                                'ดึงข้อมูลจากระบบ (บุคลากร/ศาล)',
                                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00695C),
                                side: const BorderSide(color: Color(0xFF00695C)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // 2. Scrollable Form Inputs & Printer Settings
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF1565C0), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'กรอกข้อมูลในช่องแบบพิมพ์ (${prov.activeFields.length} จุด)',
                          style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'พิมพ์ข้อความด้านล่าง หรือคลิกลากจุดข้อความบนกระดาษด้านขวาเพื่อขยับตำแหน่งสดๆ ได้ทันที',
                      style: GoogleFonts.sarabun(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),

                    ...prov.activeFields.map((field) {
                      return _buildFieldInputItem(context, prov, field);
                    }),

                    const SizedBox(height: 16),
                    _buildPrinterOffsetAndBgCard(context, prov),
                  ],
                ),
              ),
            ],
          ),
        ),

        // =====================================================================
        // CENTER PANEL: Toolbar + Interactive Live Paper Canvas
        // =====================================================================
        Expanded(
          child: Container(
            color: const Color(0xFFECEFF1),
            child: Column(
              children: [
                // Top Action & Canvas Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      // Paper Info & Zoom
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blueGrey.shade200),
                            ),
                            child: Text(
                              'ขนาด: ${prov.paperPresetCode} (${prov.paperWidthMm.toStringAsFixed(0)}×${prov.paperHeightMm.toStringAsFixed(0)} มม.)',
                              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'ซูมออก',
                            onPressed: () {
                              prov.zoomScale = (prov.zoomScale - 0.15).clamp(0.5, 2.2);
                              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                              prov.notifyListeners();
                            },
                            icon: const Icon(Icons.zoom_out, size: 20),
                          ),
                          Text(
                            '${(prov.zoomScale * 100).round()}%',
                            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          IconButton(
                            tooltip: 'ซูมเข้า',
                            onPressed: () {
                              prov.zoomScale = (prov.zoomScale + 0.15).clamp(0.5, 2.2);
                              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                              prov.notifyListeners();
                            },
                            icon: const Icon(Icons.zoom_in, size: 20),
                          ),
                          FilterChip(
                            label: Text('ตาราง มม.', style: GoogleFonts.sarabun(fontSize: 12)),
                            selected: prov.showGrid,
                            onSelected: (v) {
                              prov.showGrid = v;
                              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                              prov.notifyListeners();
                            },
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: prov.resetPositionsToTemplateDefault,
                            icon: const Icon(Icons.restart_alt, size: 17),
                            label: Text('คืนค่าตำแหน่ง', style: GoogleFonts.sarabun(fontSize: 12)),
                          ),
                        ],
                      ),

                      // Primary Print / Export PDF / Save Image Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: prov.isRendering
                                ? null
                                : () => prov.executeRenderAction('PRINT'),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: Text(
                              'พิมพ์ออกเครื่องพิมพ์',
                              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: prov.isRendering
                                ? null
                                : () => prov.executeRenderAction('EXPORT_PDF'),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: Text(
                              'บันทึก PDF',
                              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: prov.isRendering
                                ? null
                                : () => prov.executeRenderAction('EXPORT_PNG'),
                            icon: const Icon(Icons.image_rounded, size: 18),
                            label: Text(
                              'บันทึกรูป (PNG)',
                              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Live Canvas Area
                const Expanded(
                  child: LivePaperCanvas(),
                ),
              ],
            ),
          ),
        ),

        // =====================================================================
        // RIGHT PANEL: Live Position Fine-Tuner & Admin Template Designer
        // =====================================================================
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildRightInspectorPanel(context, prov),
        ),
      ],
    );
  }

  Widget _buildCatChip(String code, String label) {
    final selected = _categoryFilter == code;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.sarabun(fontSize: 11.5, fontWeight: FontWeight.w600)),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = code),
      ),
    );
  }

  Widget _buildFieldInputItem(
    BuildContext context,
    FormProvider prov,
    Map<String, dynamic> field,
  ) {
    final fId = field['id'].toString();
    final key = (field['key'] ?? '').toString();
    final label = (field['label'] ?? key).toString();
    final ftype = (field['field_type'] ?? 'text').toString();
    final isSelected = prov.selectedFieldId == fId;
    final val = prov.fieldValues[key] ?? (field['default_value'] ?? '').toString();

    if (ftype == 'checkbox' || ftype == 'cheque_cross' || ftype == 'strike_line') {
      final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(val.toLowerCase());
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: isSelected ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
          ),
        ),
        child: SwitchListTile(
          dense: true,
          title: Text(label, style: GoogleFonts.sarabun(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(
            'พิกัด X:${field['x_mm']} Y:${field['y_mm']} มม.',
            style: GoogleFonts.sarabun(fontSize: 11, color: Colors.grey.shade600),
          ),
          value: isChecked,
          onChanged: (v) {
            prov.selectField(fId);
            prov.updateFieldValue(key, v ? 'true' : 'false');
          },
        ),
      );
    }

    if (ftype == 'bahttext') {
      final autoText = prov.resolveDisplayTextForField(field);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: InkWell(
          onTap: () => prov.selectField(fId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high, size: 15, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$label (แปลงอัตโนมัติ)',
                      style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'X:${field['x_mm']} Y:${field['y_mm']}',
                    style: GoogleFonts.sarabun(fontSize: 10.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                autoText.isEmpty ? '-' : autoText,
                style: GoogleFonts.sarabun(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: ValueKey('${prov.selectedTemplate?['id']}_${fId}_$val'),
        initialValue: val,
        maxLines: ftype == 'multiline' ? 2 : 1,
        onTap: () => prov.selectField(fId),
        onChanged: (v) => prov.updateFieldValue(key, v),
        style: GoogleFonts.sarabun(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: '$label (X:${field['x_mm']}, Y:${field['y_mm']} มม.)',
          labelStyle: GoogleFonts.sarabun(
            fontSize: 12.5,
            color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          filled: true,
          fillColor: isSelected ? Colors.blue.shade50.withValues(alpha: 0.35) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: ftype == 'date_thai'
              ? IconButton(
                  tooltip: 'ใช้วันที่วันนี้',
                  icon: const Icon(Icons.today_rounded, size: 18),
                  onPressed: () {
                    final now = DateTime.now();
                    final iso =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    prov.updateFieldValue(key, iso);
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPrinterOffsetAndBgCard(BuildContext context, FormProvider prov) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF004D40)),
              const SizedBox(width: 6),
              Text(
                'ชดเชยระยะขอบเครื่องพิมพ์ & พื้นหลัง',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (prov.printerProfiles.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: null,
              decoration: InputDecoration(
                labelText: 'เลือกโปรไฟล์เครื่องพิมพ์ที่บันทึกไว้',
                labelStyle: GoogleFonts.sarabun(fontSize: 12),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: prov.printerProfiles.map((p) {
                return DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text(
                    '${p['name']} (X:${p['offset_x_mm']}, Y:${p['offset_y_mm']} มม.)',
                    style: GoogleFonts.sarabun(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  final p = prov.printerProfiles.firstWhere((e) => e['id'] == id);
                  prov.offsetXMm = (p['offset_x_mm'] as num).toDouble();
                  prov.offsetYMm = (p['offset_y_mm'] as num).toDouble();
                  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                  prov.notifyListeners();
                }
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ชดเชยซ้าย-ขวา X: ${prov.offsetXMm.toStringAsFixed(1)} มม.',
                      style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: prov.offsetXMm.clamp(-20.0, 20.0),
                      min: -20.0,
                      max: 20.0,
                      divisions: 80,
                      onChanged: (v) {
                        prov.offsetXMm = double.parse(v.toStringAsFixed(1));
                        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                        prov.notifyListeners();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ชดเชยบน-ล่าง Y: ${prov.offsetYMm.toStringAsFixed(1)} มม.',
                      style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: prov.offsetYMm.clamp(-20.0, 20.0),
                      min: -20.0,
                      max: 20.0,
                      divisions: 80,
                      onChanged: (v) {
                        prov.offsetYMm = double.parse(v.toStringAsFixed(1));
                        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                        prov.notifyListeners();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('แสดงภาพพื้นหลังทาบตำแหน่งบนหน้าจอ', style: GoogleFonts.sarabun(fontSize: 12.5)),
            value: prov.showBackgroundOnScreen,
            onChanged: (v) {
              prov.showBackgroundOnScreen = v;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              prov.notifyListeners();
            },
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'พิมพ์ภาพพื้นหลังออกเครื่องพิมพ์/PDF ด้วย',
              style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              prov.printBackgroundToPaper
                  ? 'เปิด: พิมพ์ทั้งภาพพื้นหลังและตัวอักษร'
                  : 'ปิด: พิมพ์เฉพาะตัวอักษรลงกระดาษจริง (เช่น ใบเช็ค/ซอง)',
              style: GoogleFonts.sarabun(fontSize: 11, color: Colors.deepOrange.shade800),
            ),
            value: prov.printBackgroundToPaper,
            onChanged: (v) {
              prov.printBackgroundToPaper = v;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              prov.notifyListeners();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRightInspectorPanel(BuildContext context, FormProvider prov) {
    final sf = prov.selectedField;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            const Icon(Icons.open_with_rounded, color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ปรับตำแหน่งและรูปแบบจุดที่เลือก',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sf == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'คลิกเลือกจุดข้อความบนกระดาษเพื่อขยับตำแหน่งหรือปรับขนาดตัวอักษร',
              style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sf['label']?.toString() ?? '',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'แนวนอน X: ${sf['x_mm']} มม.',
                        style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'แนวตั้ง Y: ${sf['y_mm']} มม.',
                        style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nudge Directional Pad (0.5 mm precision)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => prov.nudgeSelectedField(-0.5, 0),
                      child: const Icon(Icons.arrow_back, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      children: [
                        OutlinedButton(
                          onPressed: () => prov.nudgeSelectedField(0, -0.5),
                          child: const Icon(Icons.arrow_upward, size: 16),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: () => prov.nudgeSelectedField(0, 0.5),
                          child: const Icon(Icons.arrow_downward, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => prov.nudgeSelectedField(0.5, 0),
                      child: const Icon(Icons.arrow_forward, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'กดลูกศรเพื่อขยับละเอียดทีละ 0.5 มิลลิเมตร หรือใช้เมาส์ลากบนกระดาษ',
                    style: GoogleFonts.sarabun(fontSize: 10.5, color: Colors.blueGrey.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Font Size, Bold & Alignment
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ขนาดฟอนต์: ${(sf['font_size'] as num?)?.toStringAsFixed(0) ?? '16'} pt',
                      style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: ((sf['font_size'] as num?)?.toDouble() ?? 16.0).clamp(10.0, 36.0),
                      min: 10.0,
                      max: 36.0,
                      divisions: 26,
                      onChanged: (v) => prov.updateSelectedFieldProperty('font_size', v),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ตัวหนา (Bold)',
                onPressed: () => prov.updateSelectedFieldProperty('font_bold', !(sf['font_bold'] == true)),
                icon: Icon(
                  Icons.format_bold,
                  color: sf['font_bold'] == true ? const Color(0xFF1565C0) : Colors.grey,
                ),
              ),
            ],
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left, size: 16), label: Text('ชิดซ้าย')),
              ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center, size: 16), label: Text('กึ่งกลาง')),
              ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right, size: 16), label: Text('ชิดขวา')),
            ],
            selected: {(sf['align'] ?? 'left').toString()},
            onSelectionChanged: (set) => prov.updateSelectedFieldProperty('align', set.first),
          ),
        ],

        // =====================================================================
        // ADMIN TEMPLATE DESIGNER SECTION (Only for Admins)
        // =====================================================================
        if (prov.isFormAdmin) ...[
          const Divider(height: 28),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'เครื่องมือผู้ดูแลระบบ (Admin Designer)',
                        style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'เพิ่ม/ลบช่องข้อมูล เปลี่ยนขนาดกระดาษ อัปโหลดภาพสแกนพื้นหลัง และบันทึกเป็นงานประจำมาตรฐานให้ทุกคนใช้',
                  style: GoogleFonts.sarabun(fontSize: 11.5, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 15),
                      label: Text('เพิ่มช่องข้อความ', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'text', customLabel: 'ข้อความใหม่'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.attach_money, size: 15),
                      label: Text('เพิ่มช่องจำนวนเงิน', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'currency', customLabel: 'จำนวนเงิน'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.translate, size: 15),
                      label: Text('เพิ่มตัวอักษรบาท', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'bahttext', customLabel: 'จำนวนเงินตัวอักษร'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 15),
                      label: Text('เพิ่มวันที่ไทย', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'date_thai', customLabel: 'วันที่'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.view_week, size: 15),
                      label: Text('ช่องแยกหลัก (ปณ./เช็ค)', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'box_group', customLabel: 'รหัสแยกช่อง'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.check_box_outlined, size: 15),
                      label: Text('ช่องติ๊ก ✓', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      onPressed: () => prov.addNewField(fieldType: 'checkbox', customLabel: 'ตัวเลือก ✓'),
                    ),
                  ],
                ),
                if (sf != null) ...[
                  const Divider(height: 18),
                  TextFormField(
                    key: ValueKey('adm_lbl_${sf['id']}'),
                    initialValue: sf['label']?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: 'ชื่อเรียกช่องข้อมูล (Label)',
                      labelStyle: GoogleFonts.sarabun(fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => prov.updateSelectedFieldProperty('label', v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('adm_w_${sf['id']}'),
                          initialValue: sf['width_mm']?.toString() ?? '60',
                          decoration: InputDecoration(
                            labelText: 'ความกว้างกรอบ (มม.)',
                            labelStyle: GoogleFonts.sarabun(fontSize: 12),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null) prov.updateSelectedFieldProperty('width_mm', d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'ลบช่องข้อมูลนี้',
                        onPressed: prov.deleteSelectedField,
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 18),
                // Paper Size & Background Upload for Admin
                DropdownButtonFormField<String>(
                  initialValue: prov.paperSizes.any((p) => p['code'] == prov.paperPresetCode)
                      ? prov.paperPresetCode
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'เปลี่ยนขนาดกระดาษของแม่แบบ',
                    labelStyle: GoogleFonts.sarabun(fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(),
                  ),
                  items: prov.paperSizes.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['code'].toString(),
                      child: Text(
                        p['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sarabun(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (code) {
                    if (code != null) {
                      final p = prov.paperSizes.firstWhere((e) => e['code'] == code);
                      prov.changePaperSize(
                        code,
                        (p['width_mm'] as num).toDouble(),
                        (p['height_mm'] as num).toDouble(),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickBackgroundImage(prov),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: Text('อัปโหลดภาพทาบพื้นหลัง', style: GoogleFonts.sarabun(fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'สลับแนวตั้ง/แนวนอน',
                      onPressed: prov.swapOrientation,
                      icon: const Icon(Icons.screen_rotation_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showSaveTemplateDialog(prov, createNew: false),
                    icon: const Icon(Icons.save_rounded, size: 17),
                    label: Text(
                      'บันทึกทับแม่แบบงานประจำนี้',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showSaveTemplateDialog(prov, createNew: true),
                    icon: const Icon(Icons.add_box_rounded, size: 17),
                    label: Text(
                      'บันทึกเป็นแม่แบบงานประจำใหม่',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(height: 28),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 17, color: Colors.teal.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'คำแนะนำสำหรับผู้ใช้งาน',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'คุณสามารถขยับตำแหน่งข้อความทุกจุดบนหน้าจอเพื่อปรับให้ตรงกับกระดาษของเครื่องพิมพ์ได้ทันที โดยการขยับนี้จะมีผลเฉพาะการสั่งพิมพ์ของคุณ ไม่กระทบแม่แบบกลางของผู้ดูแลระบบ',
                  style: GoogleFonts.sarabun(fontSize: 11.5, color: Colors.teal.shade900),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
