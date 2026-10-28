import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';

class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({super.key});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  String _search = '';
  String _actionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FormProvider>(context, listen: false).loadPrintLogs();
    });
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final yearBe = dt.year + 543;
      return '${DateFormat('dd/MM/').format(dt)}$yearBe ${DateFormat('HH:mm:ss').format(dt)} น.';
    } catch (_) {
      return iso;
    }
  }

  void _showLogDetailDialog(BuildContext context, Map<String, dynamic> log) {
    final printedData = Map<String, dynamic>.from(log['printed_data'] ?? {});
    final fieldsValues = Map<String, dynamic>.from(printedData['fields_values'] ?? {});
    final positions = List<Map<String, dynamic>>.from(printedData['field_positions_mm'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: Color(0xFF00695C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'รายละเอียดประวัติการพิมพ์ #${log['id']}',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('ผู้สั่งพิมพ์:', '${log['user_full_name']} (${log['username']}) • ${log['department']}'),
                  _infoRow('วัน-เวลาที่พิมพ์:', _formatDateTime(log['created_at']?.toString())),
                  _infoRow('งานประจำ / แม่แบบ:', '${log['template_name']} (${log['paper_size_label']})'),
                  _infoRow('รูปแบบคำสั่ง:', '${log['action_display']} (${log['page_count']} แผ่น)'),
                  _infoRow('ระยะชดเชยเครื่องพิมพ์:', 'X: ${log['offset_x_mm']} มม., Y: ${log['offset_y_mm']} มม.'),
                  _infoRow('IP Address:', log['ip_address']?.toString() ?? '-'),
                  if ((log['data_source_used'] ?? '').toString().isNotEmpty)
                    _infoRow('แหล่งข้อมูลที่ใช้:', log['data_source_used'].toString()),
                  const Divider(height: 24),
                  Text(
                    'ข้อมูลที่กรอกและพิมพ์ออกไปจริง:',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF004D40)),
                  ),
                  const SizedBox(height: 8),
                  if (fieldsValues.isEmpty)
                    Text('ไม่มีข้อมูลช่องข้อความ', style: GoogleFonts.sarabun())
                  else
                    ...fieldsValues.entries.map((e) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 190,
                              child: Text(
                                e.key,
                                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value.toString(),
                                style: GoogleFonts.sarabun(fontSize: 13.5, color: Colors.blueGrey.shade900),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (positions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'พิกัดบนกระดาษขณะสั่งพิมพ์ (หน่วยมิลลิเมตร):',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: positions.map((p) {
                        return Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${p['label']}: (X:${p['x_mm']}, Y:${p['y_mm']} มม.)',
                            style: GoogleFonts.sarabun(fontSize: 11.5),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('ปิดหน้าต่าง', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.sarabun(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final totalJobs = prov.printLogSummary['total_jobs'] ?? prov.printLogs.length;
    final totalPages = prov.printLogSummary['total_pages'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Summary Cards
          Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: Color(0xFF004D40), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ประวัติการพิมพ์และส่งออกเอกสาร (Print Audit Logs)',
                      style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'บันทึกทุกครั้งที่มีการสั่งพิมพ์ออกเครื่องพิมพ์ บันทึก PDF หรือบันทึกรูปภาพ ว่าพิมพ์อะไรไป โดยใคร เมื่อไหร่',
                      style: GoogleFonts.sarabun(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              _summaryBadge('จำนวนครั้งที่พิมพ์รวม', '$totalJobs ครั้ง', const Color(0xFF00695C)),
              const SizedBox(width: 12),
              _summaryBadge('จำนวนกระดาษที่พิมพ์รวม', '$totalPages แผ่น', const Color(0xFF1565C0)),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อผู้พิมพ์ / ชื่อแม่แบบ / ข้อความที่พิมพ์ (เช่น ชื่อผู้รับเช็ค, ชื่อศาล)...',
                    hintStyle: GoogleFonts.sarabun(fontSize: 13),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) {
                    _search = v;
                    prov.loadPrintLogs(search: _search, actionType: _actionFilter);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue: _actionFilter,
                  decoration: InputDecoration(
                    labelText: 'กรองตามประเภทคำสั่ง',
                    labelStyle: GoogleFonts.sarabun(fontSize: 12.5),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('ทุกประเภทการพิมพ์')),
                    DropdownMenuItem(value: 'PRINT', child: Text('สั่งพิมพ์ออกเครื่องพิมพ์')),
                    DropdownMenuItem(value: 'EXPORT_PDF', child: Text('บันทึกเป็นไฟล์ PDF')),
                    DropdownMenuItem(value: 'EXPORT_PNG', child: Text('บันทึกเป็นรูปภาพ (PNG)')),
                    DropdownMenuItem(value: 'BATCH_PDF', child: Text('พิมพ์ต่อเนื่องหลายแผ่น (Batch)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _actionFilter = v);
                      prov.loadPrintLogs(search: _search, actionType: _actionFilter);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => prov.loadPrintLogs(search: _search, actionType: _actionFilter),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('รีเฟรช', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Logs Table
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: prov.printLogs.isEmpty
                  ? Center(
                      child: Text(
                        'ยังไม่มีประวัติการพิมพ์ตามเงื่อนไขที่ค้นหา',
                        style: GoogleFonts.sarabun(fontSize: 15, color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: prov.printLogs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final log = prov.printLogs[idx];
                        final actionType = (log['action_type'] ?? 'PRINT').toString();
                        Color badgeColor = const Color(0xFF00695C);
                        if (actionType == 'EXPORT_PDF' || actionType == 'BATCH_PDF') {
                          badgeColor = const Color(0xFFD32F2F);
                        } else if (actionType == 'EXPORT_PNG') {
                          badgeColor = const Color(0xFF1565C0);
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              log['action_display']?.toString() ?? actionType,
                              style: GoogleFonts.sarabun(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                log['template_name']?.toString() ?? '',
                                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14.5),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${log['page_count']} แผ่น • ${log['paper_size_label']}',
                                  style: GoogleFonts.sarabun(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ข้อมูลที่พิมพ์: ${log['summary_text'] ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sarabun(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'โดย: ${log['user_full_name']} (${log['username']}) • ${log['department']} • เวลา: ${_formatDateTime(log['created_at']?.toString())} • IP: ${log['ip_address']}',
                                  style: GoogleFonts.sarabun(fontSize: 11.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          trailing: OutlinedButton.icon(
                            onPressed: () => _showLogDetailDialog(context, log),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: Text('ดูข้อมูลที่พิมพ์', style: GoogleFonts.sarabun(fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: GoogleFonts.sarabun(fontSize: 11.5, color: color)),
          Text(
            value,
            style: GoogleFonts.sarabun(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
