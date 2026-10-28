import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';

class CourtHeader extends StatelessWidget implements PreferredSizeWidget {
  const CourtHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF0D47A1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.print_rounded, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        prov.courtName,
                        style: GoogleFonts.sarabun(
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(Court Smart Form & Print Studio)',
                          style: GoogleFonts.sarabun(
                            fontSize: 12,
                            color: Colors.teal.shade100,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'ระบบออกแบบและจัดพิมพ์แบบฟอร์มอัจฉริยะ (A4 / A5 / ซองจดหมาย / สมุดเช็ค)',
                        style: GoogleFonts.sarabun(
                          fontSize: isCompact ? 11.5 : 12.5,
                          color: Colors.teal.shade50,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: prov.isFormAdmin
                              ? Colors.amber.shade700
                              : Colors.lightBlue.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          prov.isFormAdmin ? 'สิทธิ์: ADMIN (ผู้ดูแลแม่แบบ)' : 'สิทธิ์: ผู้ใช้งานทั่วไป',
                          style: GoogleFonts.sarabun(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (prov.isAuthenticated && !isCompact)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          prov.displayName,
                          style: GoogleFonts.sarabun(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${prov.position} • ${prov.department}',
                          style: GoogleFonts.sarabun(
                            fontSize: 10.5,
                            color: Colors.teal.shade100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ElevatedButton.icon(
              onPressed: prov.logoutToPortal,
              icon: const Icon(Icons.apps_rounded, size: 17),
              label: Text(
                isCompact ? 'Portal' : 'กลับสู่ระบบหลัก (Portal)',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF004D40),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
