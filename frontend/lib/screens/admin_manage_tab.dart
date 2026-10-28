import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';

class AdminManageTab extends StatelessWidget {
  final VoidCallback onOpenDesigner;
  const AdminManageTab({super.key, required this.onOpenDesigner});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);

    if (!prov.isFormAdmin) {
      return Center(
        child: Text(
          'เฉพาะผู้ดูแลระบบ (Admin) เท่านั้นที่มีสิทธิ์จัดการแม่แบบงานประจำและตั้งค่าแหล่งข้อมูล',
          style: GoogleFonts.sarabun(fontSize: 16, color: Colors.red.shade700),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Manage Data Sources & Permissions
          Row(
            children: [
              const Icon(Icons.security_rounded, color: Color(0xFF00695C), size: 26),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. จัดการสิทธิ์และการกรองแหล่งข้อมูลในระบบ (Data Source Governance)',
                    style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ควบคุมว่าอนุญาตให้นำข้อมูลใดในระบบกลางออกมาใช้พิมพ์ได้บ้าง พร้อมกำหนดเงื่อนไขการกรองข้อมูล',
                    style: GoogleFonts.sarabun(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: prov.dataSources.map((ds) {
              final id = ds['id'] as int;
              final isEnabled = ds['is_enabled'] == true;
              final sameCourt = ds['same_court_only'] == true;
              final activeOnly = ds['active_only'] == true;
              final availFields = List<Map<String, dynamic>>.from(ds['available_fields'] ?? []);
              final exposedList = List<String>.from(ds['exposed_fields'] ?? []);

              return Container(
                width: 540,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnabled ? Colors.teal.shade300 : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEnabled ? Icons.check_circle : Icons.block,
                          color: isEnabled ? Colors.teal.shade700 : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ds['name'].toString(),
                            style: GoogleFonts.sarabun(fontSize: 15.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          onChanged: (v) {
                            prov.updateDataSourceSetting(id, {'is_enabled': v});
                          },
                        ),
                      ],
                    ),
                    Text(
                      ds['description']?.toString() ?? '',
                      style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const Divider(height: 18),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'กรองเฉพาะรายการที่เปิดใช้งานอยู่ (Active Only)',
                        style: GoogleFonts.sarabun(fontSize: 13),
                      ),
                      value: activeOnly,
                      onChanged: (v) {
                        prov.updateDataSourceSetting(id, {'active_only': v == true});
                      },
                    ),
                    if (ds['source_code'] == 'portal_users')
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'กรองเฉพาะบุคลากรในสังกัดศาลเดียวกันกับผู้สั่งพิมพ์',
                          style: GoogleFonts.sarabun(fontSize: 13),
                        ),
                        value: sameCourt,
                        onChanged: (v) {
                          prov.updateDataSourceSetting(id, {'same_court_only': v == true});
                        },
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'ฟิลด์ข้อมูลที่อนุญาตให้นำออกมาใช้พิมพ์:',
                      style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availFields.map((f) {
                        final fKey = f['key'].toString();
                        final fLbl = f['label'].toString();
                        final selected = exposedList.contains(fKey);
                        return FilterChip(
                          label: Text(fLbl, style: GoogleFonts.sarabun(fontSize: 11.5)),
                          selected: selected,
                          onSelected: (val) {
                            final updated = List<String>.from(exposedList);
                            if (val) {
                              if (!updated.contains(fKey)) updated.add(fKey);
                            } else {
                              if (updated.length > 1) updated.remove(fKey);
                            }
                            prov.updateDataSourceSetting(id, {'exposed_fields': updated});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 2: Manage Routine Templates
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF1565C0), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. จัดการคลังแม่แบบงานประจำ (Routine Templates — ${prov.templates.length} แบบ)',
                      style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'คลิกเลือกแม่แบบเพื่อเปิดแก้ไขจุดวางข้อมูล ขนาดกระดาษ หรือสำเนาเป็นงานประจำแบบใหม่',
                      style: GoogleFonts.sarabun(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prov.templates.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final t = prov.templates[idx];
                final id = t['id'] as int;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00695C).withValues(alpha: 0.12),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF00695C)),
                  ),
                  title: Text(
                    t['name'].toString(),
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    'หมวด: ${t['category']} • ขนาดกระดาษ: ${t['paper_preset']} (${t['width_mm']}×${t['height_mm']} มม.) • จำนวนช่องข้อมูล: ${t['field_count'] ?? (t['fields_schema'] as List?)?.length ?? 0} จุด',
                    style: GoogleFonts.sarabun(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          prov.selectTemplate(t);
                          onOpenDesigner();
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text('แก้ไขในหน้าออกแบบ', style: GoogleFonts.sarabun(fontSize: 12.5)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => prov.duplicateTemplateById(id),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text('ทำสำเนา', style: GoogleFonts.sarabun(fontSize: 12.5)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'ลบแม่แบบนี้',
                        onPressed: prov.templates.length <= 1
                            ? null
                            : () => prov.deleteTemplateById(id),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
