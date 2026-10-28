import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/form_provider.dart';
import 'screens/admin_logs_tab.dart';
import 'screens/admin_manage_tab.dart';
import 'screens/batch_merge_tab.dart';
import 'screens/workspace_tab.dart';
import 'widgets/court_header.dart';

void main(List<String> args) {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FormProvider()..initialize(cliArgs: args),
      child: const CourtFormApp(),
    ),
  );
}

class CourtFormApp extends StatelessWidget {
  const CourtFormApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบออกแบบและจัดพิมพ์แบบฟอร์มอัจฉริยะ - ศาลแขวงเชียงดาว',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
        textTheme: GoogleFonts.sarabunTextTheme(),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _activeTabIndex = 0;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);

    if (prov.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'กำลังเชื่อมต่อระบบ Court Central Portal (SSO)...',
                style: GoogleFonts.sarabun(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (!prov.isAuthenticated) {
      return _buildPortalLoginGateway(context, prov);
    }

    final isAdmin = prov.isFormAdmin;
    final showServerAdminTabs = isAdmin && !prov.isLiteMode;

    final tabs = <Widget>[
      WorkspaceTab(onSwitchToBatchTab: () => setState(() => _activeTabIndex = 1)),
      const BatchMergeTab(),
      if (showServerAdminTabs) AdminManageTab(onOpenDesigner: () => setState(() => _activeTabIndex = 0)),
      if (showServerAdminTabs) const AdminLogsTab(),
    ];

    final safeIdx = _activeTabIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: const CourtHeader(),
      body: Column(
        children: [
          // Navigation Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                _navTabButton(
                  index: 0,
                  currentIndex: safeIdx,
                  icon: Icons.design_services_rounded,
                  label: '1. กรอกและขยับแบบพิมพ์สด (Live Canvas)',
                ),
                const SizedBox(width: 8),
                _navTabButton(
                  index: 1,
                  currentIndex: safeIdx,
                  icon: Icons.library_books_rounded,
                  label: prov.isLiteMode
                      ? '2. พิมพ์ต่อเนื่องหลายแผ่น (CSV Batch)'
                      : '2. พิมพ์ต่อเนื่องหลายแผ่น (Batch / Excel / Data Source)',
                ),
                if (showServerAdminTabs) ...[
                  const SizedBox(width: 8),
                  _navTabButton(
                    index: 2,
                    currentIndex: safeIdx,
                    icon: Icons.settings_suggest_rounded,
                    label: '3. จัดการแม่แบบ & แหล่งข้อมูลที่อนุญาต (Admin)',
                  ),
                  const SizedBox(width: 8),
                  _navTabButton(
                    index: 3,
                    currentIndex: safeIdx,
                    icon: Icons.history_edu_rounded,
                    label: '4. ประวัติการพิมพ์ Audit Log (Admin)',
                  ),
                ],
                const Spacer(),
                if (prov.isRendering)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'กำลังสร้างเอกสารความละเอียดสูง...',
                        style: GoogleFonts.sarabun(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tabs[safeIdx],
          ),
        ],
      ),
    );
  }

  Widget _navTabButton({
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
  }) {
    final active = index == currentIndex;
    return ElevatedButton.icon(
      onPressed: () => setState(() => _activeTabIndex = index),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.sarabun(
          fontSize: 13,
          fontWeight: active ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? const Color(0xFF00695C) : Colors.grey.shade100,
        foregroundColor: active ? Colors.white : Colors.blueGrey.shade800,
        elevation: active ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPortalLoginGateway(BuildContext context, FormProvider prov) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: const CourtHeader(),
      body: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.lock_person_rounded, size: 34, color: Color(0xFF00695C)),
                ),
                const SizedBox(height: 14),
                Text(
                  'เข้าสู่ระบบผ่าน Court Central Portal',
                  style: GoogleFonts.sarabun(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'ระบบนี้ออกแบบให้เข้าใช้งานผ่านระบบรวมศูนย์ (Single Sign-On) หรือยืนยันตัวตนด้วยบัญชีผู้ใช้งานกลางของศาลแขวงเชียงดาว',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sarabun(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (prov.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prov.errorMessage!,
                      style: GoogleFonts.sarabun(color: Colors.red.shade800, fontSize: 12.5),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(
                    labelText: 'ชื่อผู้ใช้งาน (Username)',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  onSubmitted: (_) => prov.loginWithCredentials(_userCtrl.text, _passCtrl.text),
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน (Password)',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => prov.loginWithCredentials(_userCtrl.text, _passCtrl.text),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      'เข้าสู่ระบบ',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: prov.logoutToPortal,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    'ไปที่หน้า Court Central Portal (พอร์ต 8888)',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: prov.switchToLiteMode,
                    icon: const Icon(Icons.offline_bolt_rounded, size: 18),
                    label: Text(
                      'เข้าใช้งานโหมด Lite (Standalone พิมพ์อิสระไม่ต้องล็อกอิน)',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange.shade800,
                      side: BorderSide(color: Colors.deepOrange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
