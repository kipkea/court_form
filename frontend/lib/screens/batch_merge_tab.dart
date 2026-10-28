import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import '../widgets/datasource_picker_dialog.dart';
import '../widgets/live_paper_canvas.dart';

class BatchMergeTab extends StatelessWidget {
  const BatchMergeTab({super.key});

  Future<void> _pickCsvOrExcel(BuildContext context, FormProvider prov) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (files.isNotEmpty) {
      final f = files.first;
      try {
        final bytes = await f.readAsBytes();
        await prov.uploadAndParseBatchFile(bytes, f.name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'นำเข้าไฟล์ ${f.name} สำเร็จ (${prov.batchRows.length} รายการ)',
                style: GoogleFonts.sarabun(),
              ),
              backgroundColor: Colors.teal.shade700,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไม่สามารถอ่านไฟล์ได้: $e', style: GoogleFonts.sarabun()),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final hasBatch = prov.batchRows.isNotEmpty;
    final currentPreviewValues = hasBatch
        ? prov.buildMappedValuesForRow(
            prov.batchRows[prov.batchPreviewIndex.clamp(0, prov.batchRows.length - 1)],
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Configuration Panel
        Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.library_books_rounded, color: Color(0xFF1565C0), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'พิมพ์ต่อเนื่องหลายแผ่น (Batch / Mail Merge)',
                      style: GoogleFonts.sarabun(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'นำเข้าข้อมูลจากไฟล์ Excel (.xlsx) / CSV หรือเลือกหลายรายการจากฐานข้อมูลศาล/บุคลากร เพื่อสั่งพิมพ์ซองจดหมาย เช็ค หรือแบบฟอร์มต่อเนื่องหลายแผ่นในครั้งเดียว',
                style: GoogleFonts.sarabun(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickCsvOrExcel(context, prov),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(
                        'อัปโหลด Excel / CSV',
                        style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const DataSourcePickerDialog(),
                        );
                      },
                      icon: const Icon(Icons.storage_rounded, size: 18),
                      label: Text(
                        'เลือกจากข้อมูลในระบบ',
                        style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (!hasBatch)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_view_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'ยังไม่มีชุดข้อมูลสำหรับพิมพ์ต่อเนื่อง',
                          style: GoogleFonts.sarabun(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'กดปุ่ม "อัปโหลด Excel / CSV" หรือ "เลือกจากข้อมูลในระบบ" ด้านบน',
                          style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF00695C), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          prov.batchSourceLabel,
                          style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'จับคู่คอลัมน์ข้อมูลเข้ากับช่องบนแบบพิมพ์ (${prov.selectedTemplate?['name'] ?? ''})',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: prov.activeFields.length,
                    itemBuilder: (context, idx) {
                      final f = prov.activeFields[idx];
                      final ftype = (f['field_type'] ?? 'text').toString();
                      if (ftype == 'static_text' || ftype == 'bahttext') {
                        return const SizedBox.shrink();
                      }
                      final fKey = (f['key'] ?? '').toString();
                      final fLabel = (f['label'] ?? fKey).toString();
                      final currentCol = prov.batchFieldMapping[fKey] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          initialValue: prov.batchColumns.contains(currentCol) ? currentCol : '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'ช่อง: $fLabel',
                            labelStyle: GoogleFonts.sarabun(fontSize: 12.5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('-- ใช้ค่าคงที่จากหน้าหลัก --', style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey)),
                            ),
                            ...prov.batchColumns.map((col) {
                              return DropdownMenuItem<String>(
                                value: col,
                                child: Text(
                                  'คอลัมน์: $col',
                                  style: GoogleFonts.sarabun(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            prov.batchFieldMapping[fKey] = val ?? '';
                            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                            prov.notifyListeners();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: prov.isRendering
                        ? null
                        : () {
                            final allRecords = prov.batchRows
                                .map((row) => prov.buildMappedValuesForRow(row))
                                .toList();
                            prov.executeRenderAction('BATCH_PDF', customRecords: allRecords);
                          },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: Text(
                      'สร้างและดาวน์โหลด PDF รวมทั้งหมด (${prov.batchRows.length} แผ่น)',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Right Preview Area
        Expanded(
          child: Container(
            color: const Color(0xFFECEFF1),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Text(
                        hasBatch
                            ? 'พรีวิวแผ่นที่ ${prov.batchPreviewIndex + 1} จากทั้งหมด ${prov.batchRows.length} แผ่น'
                            : 'ตัวอย่างกระดาษ',
                        style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      if (hasBatch) ...[
                        OutlinedButton.icon(
                          onPressed: prov.batchPreviewIndex > 0
                              ? () {
                                  prov.batchPreviewIndex--;
                                  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                                  prov.notifyListeners();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: Text('แผ่นก่อนหน้า', style: GoogleFonts.sarabun(fontSize: 12.5)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: prov.batchPreviewIndex < prov.batchRows.length - 1
                              ? () {
                                  prov.batchPreviewIndex++;
                                  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                                  prov.notifyListeners();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: Text('แผ่นถัดไป', style: GoogleFonts.sarabun(fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: LivePaperCanvas(overrideValues: currentPreviewValues),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
