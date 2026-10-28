import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';

class DataSourcePickerDialog extends StatefulWidget {
  final String? initialSourceCode;
  final VoidCallback? onSwitchToBatchTab;

  const DataSourcePickerDialog({
    super.key,
    this.initialSourceCode,
    this.onSwitchToBatchTab,
  });

  @override
  State<DataSourcePickerDialog> createState() => _DataSourcePickerDialogState();
}

class _DataSourcePickerDialogState extends State<DataSourcePickerDialog> {
  String _selectedSource = 'portal_users';
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _fieldsMeta = [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<FormProvider>(context, listen: false);
    if (widget.initialSourceCode != null && widget.initialSourceCode!.isNotEmpty) {
      _selectedSource = widget.initialSourceCode!;
    } else if (prov.dataSources.isNotEmpty) {
      _selectedSource = prov.dataSources.first['source_code'].toString();
    }
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prov = Provider.of<FormProvider>(context, listen: false);
      final res = await prov.queryDataSourceRecords(_selectedSource, search: _search);
      setState(() {
        _records = List<Map<String, dynamic>>.from(res['records'] ?? []);
        _fieldsMeta = List<Map<String, dynamic>>.from(res['fields'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถดึงข้อมูลได้ หรือแหล่งข้อมูลนี้ถูกปิดการอนุญาตโดย Admin';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final enabledSources = prov.dataSources.where((d) => d['is_enabled'] == true).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: Color(0xFF00695C), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ดึงข้อมูลในระบบมาพิมพ์อัตโนมัติ (Data Source ที่ได้รับอนุญาต)',
                        style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'เลือกรายการเพื่อเติมข้อมูลลงในช่องแบบพิมพ์ทันที หรือเลือกหลายรายการเพื่อสั่งพิมพ์ต่อเนื่องหลายแผ่น',
                        style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: enabledSources.any((e) => e['source_code'] == _selectedSource)
                        ? _selectedSource
                        : (enabledSources.isNotEmpty ? enabledSources.first['source_code'].toString() : null),
                    decoration: InputDecoration(
                      labelText: 'เลือกชุดข้อมูลที่อนุญาต',
                      labelStyle: GoogleFonts.sarabun(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: enabledSources.map((src) {
                      return DropdownMenuItem<String>(
                        value: src['source_code'].toString(),
                        child: Text(
                          src['name'].toString(),
                          style: GoogleFonts.sarabun(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSource = val;
                          _selectedIds.clear();
                        });
                        _fetchRecords();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อ / ตำแหน่ง / หน่วยงาน / จังหวัด...',
                      hintStyle: GoogleFonts.sarabun(fontSize: 13),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) {
                      _search = v;
                      _fetchRecords();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'พบข้อมูลที่อนุญาต ${_records.length} รายการ',
                  style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == _records.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(_records.map((r) => (r['id'] as num).toInt()));
                      }
                    });
                  },
                  icon: Icon(
                    _selectedIds.length == _records.length && _records.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 16,
                  ),
                  label: Text(
                    _selectedIds.length == _records.length && _records.isNotEmpty
                        ? 'ยกเลิกเลือกทั้งหมด'
                        : 'เลือกทั้งหมดเพื่อพิมพ์ชุด (${_records.length})',
                    style: GoogleFonts.sarabun(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: GoogleFonts.sarabun(color: Colors.red.shade700, fontSize: 14),
                          ),
                        )
                      : _records.isEmpty
                          ? Center(
                              child: Text(
                                'ไม่พบรายการข้อมูล',
                                style: GoogleFonts.sarabun(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _records.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final rec = _records[idx];
                                final id = (rec['id'] as num).toInt();
                                final checked = _selectedIds.contains(id);
                                return ListTile(
                                  dense: true,
                                  leading: Checkbox(
                                    value: checked,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    (rec['_display_title'] ?? '').toString(),
                                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    (rec['_display_subtitle'] ?? '').toString(),
                                    style: GoogleFonts.sarabun(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () {
                                      prov.applyDataSourceRecordToForm(_selectedSource, rec);
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'ดึงข้อมูล "${rec['_display_title']}" ลงแบบพิมพ์เรียบร้อยแล้ว',
                                            style: GoogleFonts.sarabun(),
                                          ),
                                          backgroundColor: Colors.teal.shade700,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.download_done_rounded, size: 16),
                                    label: Text('ใช้รายการนี้', style: GoogleFonts.sarabun(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00695C),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_selectedIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      final chosen = _records
                          .where((r) => _selectedIds.contains((r['id'] as num).toInt()))
                          .toList();
                      final srcName = enabledSources
                              .firstWhere(
                                (e) => e['source_code'] == _selectedSource,
                                orElse: () => {'name': _selectedSource},
                              )['name']
                              .toString();
                      prov.loadDataSourceRecordsIntoBatch(
                        _selectedSource,
                        srcName,
                        chosen,
                        _fieldsMeta,
                      );
                      Navigator.of(context).pop();
                      widget.onSwitchToBatchTab?.call();
                    },
                    icon: const Icon(Icons.library_books_rounded, size: 18),
                    label: Text(
                      'นำ ${_selectedIds.length} รายการที่เลือกไปพิมพ์ต่อเนื่อง (Batch)',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('ปิดหน้าต่าง', style: GoogleFonts.sarabun()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
