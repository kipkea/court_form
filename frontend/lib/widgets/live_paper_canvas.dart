import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';

class LivePaperCanvas extends StatelessWidget {
  final Map<String, String>? overrideValues;
  const LivePaperCanvas({super.key, this.overrideValues});

  static const double basePxPerMm = 3.6;

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<FormProvider>(context);
    final scale = basePxPerMm * prov.zoomScale;
    final paperW = prov.paperWidthMm * scale;
    final paperH = prov.paperHeightMm * scale;
    const rulerThickness = 24.0;

    Uint8List? bgBytes;
    if (prov.showBackgroundOnScreen && prov.backgroundImage.isNotEmpty) {
      try {
        final raw = prov.backgroundImage.contains(',')
            ? prov.backgroundImage.split(',').last
            : prov.backgroundImage;
        bgBytes = base64Decode(raw);
      } catch (_) {}
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(120),
          minScale: 0.4,
          maxScale: 2.5,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Horizontal Ruler (mm)
                Row(
                  children: [
                    Container(
                      width: rulerThickness,
                      height: rulerThickness,
                      color: const Color(0xFF263238),
                      child: const Center(
                        child: Text(
                          'มม.',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: Size(paperW, rulerThickness),
                      painter: _HorizontalRulerPainter(
                        widthMm: prov.paperWidthMm,
                        scale: scale,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Vertical Ruler (mm)
                    CustomPaint(
                      size: Size(rulerThickness, paperH),
                      painter: _VerticalRulerPainter(
                        heightMm: prov.paperHeightMm,
                        scale: scale,
                      ),
                    ),
                    // Actual Paper Surface
                    Container(
                      width: paperW,
                      height: paperH,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                        border: Border.all(color: Colors.blueGrey.shade300, width: 1),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Background Reference Image (e.g. Scanned Cheque or Form)
                          if (bgBytes != null)
                            Positioned.fill(
                              child: Opacity(
                                opacity: prov.printBackgroundToPaper ? 1.0 : 0.72,
                                child: Image.memory(
                                  bgBytes,
                                  fit: BoxFit.fill,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),

                          // 2. Millimeter Grid Overlay
                          if (prov.showGrid)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _MillimeterGridPainter(
                                  widthMm: prov.paperWidthMm,
                                  heightMm: prov.paperHeightMm,
                                  gridMm: prov.gridSizeMm,
                                  scale: scale,
                                ),
                              ),
                            ),

                          // 3. Background Print Mode Status Pill (Top-Right inside paper)
                          if (prov.backgroundImage.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: prov.printBackgroundToPaper
                                        ? Colors.teal.shade700.withValues(alpha: 0.85)
                                        : Colors.deepOrange.shade700.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    prov.printBackgroundToPaper
                                        ? 'โหมด: พิมพ์พื้นหลังออกกระดาษด้วย'
                                        : 'โหมดทาบตำแหน่ง: พิมพ์เฉพาะตัวอักษรลงกระดาษจริง',
                                    style: GoogleFonts.sarabun(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 4. Draggable Form Fields
                          ...prov.activeFields.map((field) {
                            return _buildDraggableFieldWidget(
                              context,
                              prov,
                              field,
                              scale,
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableFieldWidget(
    BuildContext context,
    FormProvider prov,
    Map<String, dynamic> field,
    double scale,
  ) {
    final fieldId = field['id'].toString();
    final isSelected = prov.selectedFieldId == fieldId;
    final ftype = (field['field_type'] ?? 'text').toString();

    final xMm = ((field['x_mm'] as num?)?.toDouble() ?? 0.0) + prov.offsetXMm;
    final yMm = ((field['y_mm'] as num?)?.toDouble() ?? 0.0) + prov.offsetYMm;
    final wMm = (field['width_mm'] as num?)?.toDouble() ?? 60.0;
    final hMm = (field['height_mm'] as num?)?.toDouble() ?? 8.5;
    final fontSizePt = (field['font_size'] as num?)?.toDouble() ?? 16.0;
    final isBold = field['font_bold'] == true;
    final alignStr = (field['align'] ?? 'left').toString();

    final leftPx = xMm * scale;
    final topPx = yMm * scale;
    final widthPx = math.max(20.0, wMm * scale);
    final heightPx = math.max(16.0, hMm * scale);
    // 1 pt = 0.352778 mm; THSarabunNew on screen scaled to match ReportLab
    final screenFontPx = fontSizePt * 0.36 * scale;

    final rawVal = (overrideValues ?? prov.fieldValues)[field['key']] ??
        (field['default_value'] ?? '').toString();
    final displayText = prov.resolveDisplayTextForField(
      field,
      customValues: overrideValues,
    );

    Widget contentWidget;

    if (ftype == 'cheque_cross') {
      final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
      contentWidget = isChecked
          ? Transform.rotate(
              angle: -0.52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFB71C1C), width: 2),
                    bottom: BorderSide(color: Color(0xFFB71C1C), width: 2),
                  ),
                ),
                child: Text(
                  (field['cross_text'] ?? 'A/C PAYEE ONLY').toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sarabun(
                    fontSize: math.max(9, screenFontPx * 0.8),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
              ),
            )
          : Text(
              '[ไม่ขีดคร่อม]',
              style: GoogleFonts.sarabun(fontSize: 10, color: Colors.grey),
            );
    } else if (ftype == 'strike_line') {
      final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
      contentWidget = Center(
        child: Container(
          height: 2.5,
          width: widthPx,
          color: isChecked ? Colors.black87 : Colors.grey.withValues(alpha: 0.3),
        ),
      );
    } else if (ftype == 'checkbox') {
      final isChecked = ['true', '1', 'yes', 'on', '✓'].contains(rawVal.toLowerCase());
      final drawBox = field['draw_box'] == true;
      contentWidget = Container(
        width: heightPx,
        height: heightPx,
        decoration: BoxDecoration(
          border: drawBox ? Border.all(color: Colors.black87, width: 1.2) : null,
        ),
        child: Center(
          child: isChecked
              ? Icon(Icons.check, size: heightPx * 0.85, color: Colors.black)
              : const SizedBox.shrink(),
        ),
      );
    } else if (ftype == 'box_group') {
      final spacingMm = (field['letter_spacing_mm'] as num?)?.toDouble() ?? 5.8;
      final spacingPx = spacingMm * scale;
      final chars = displayText.replaceAll(' ', '').split('');
      final maxBoxes = (field['max_boxes'] as num?)?.toInt() ?? chars.length;
      contentWidget = SizedBox(
        width: math.max(widthPx, maxBoxes * spacingPx),
        height: heightPx,
        child: Stack(
          children: List.generate(math.min(chars.length, maxBoxes), (idx) {
            return Positioned(
              left: idx * spacingPx,
              top: 0,
              width: spacingPx,
              height: heightPx,
              child: Center(
                child: Text(
                  chars[idx],
                  style: GoogleFonts.sarabun(
                    fontSize: screenFontPx,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
              ),
            );
          }),
        ),
      );
    } else {
      TextAlign tAlign = TextAlign.left;
      Alignment boxAlign = Alignment.topLeft;
      if (alignStr == 'center') {
        tAlign = TextAlign.center;
        boxAlign = Alignment.topCenter;
      } else if (alignStr == 'right') {
        tAlign = TextAlign.right;
        boxAlign = Alignment.topRight;
      }

      final showPlaceholder = displayText.trim().isEmpty;
      contentWidget = Container(
        width: widthPx,
        constraints: BoxConstraints(minHeight: heightPx),
        alignment: boxAlign,
        decoration: field['draw_border'] == true
            ? BoxDecoration(border: Border.all(color: Colors.black54, width: 0.8))
            : null,
        child: Text(
          showPlaceholder ? '[${field['label'] ?? field['key']}]' : displayText,
          textAlign: tAlign,
          style: GoogleFonts.sarabun(
            fontSize: screenFontPx,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: showPlaceholder
                ? Colors.blueGrey.shade400
                : _parseColor(field['color']?.toString()),
            height: 1.12,
          ),
        ),
      );
    }

    return Positioned(
      left: leftPx,
      top: topPx,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => prov.selectField(fieldId),
        onPanStart: (_) => prov.selectField(fieldId),
        onPanUpdate: (details) {
          final dxMm = details.delta.dx / scale;
          final dyMm = details.delta.dy / scale;
          final curX = (field['x_mm'] as num?)?.toDouble() ?? 0.0;
          final curY = (field['y_mm'] as num?)?.toDouble() ?? 0.0;
          prov.moveFieldPosition(fieldId, curX + dxMm, curY + dyMm);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.10)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1565C0)
                        : Colors.blueGrey.withValues(alpha: 0.35),
                    width: isSelected ? 1.6 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: contentWidget,
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  top: -19,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${field['label']} (X:${field['x_mm']} Y:${field['y_mm']} มม.)',
                      style: GoogleFonts.sarabun(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty || !hex.startsWith('#') || hex.length != 7) {
      return Colors.black87;
    }
    try {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    } catch (_) {
      return Colors.black87;
    }
  }
}

class _HorizontalRulerPainter extends CustomPainter {
  final double widthMm;
  final double scale;
  _HorizontalRulerPainter({required this.widthMm, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final tickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    final totalMm = widthMm.ceil();
    for (int m = 0; m <= totalMm; m++) {
      final x = m * scale;
      if (x > size.width) break;
      final isMajor = m % 10 == 0;
      final isMid = m % 5 == 0;
      final tickH = isMajor ? 11.0 : (isMid ? 7.0 : 4.0);
      canvas.drawLine(
        Offset(x, size.height - tickH),
        Offset(x, size.height),
        tickPaint,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$m',
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulerPainter old) =>
      old.widthMm != widthMm || old.scale != scale;
}

class _VerticalRulerPainter extends CustomPainter {
  final double heightMm;
  final double scale;
  _VerticalRulerPainter({required this.heightMm, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final tickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    final totalMm = heightMm.ceil();
    for (int m = 0; m <= totalMm; m++) {
      final y = m * scale;
      if (y > size.height) break;
      final isMajor = m % 10 == 0;
      final isMid = m % 5 == 0;
      final tickW = isMajor ? 11.0 : (isMid ? 7.0 : 4.0);
      canvas.drawLine(
        Offset(size.width - tickW, y),
        Offset(size.width, y),
        tickPaint,
      );
      if (isMajor && m > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$m',
            style: const TextStyle(color: Colors.white, fontSize: 8.5),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(2, y + 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter old) =>
      old.heightMm != heightMm || old.scale != scale;
}

class _MillimeterGridPainter extends CustomPainter {
  final double widthMm;
  final double heightMm;
  final double gridMm;
  final double scale;

  _MillimeterGridPainter({
    required this.widthMm,
    required this.heightMm,
    required this.gridMm,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final step = (gridMm <= 0 ? 5.0 : gridMm) * scale;
    if (step < 4) return;

    final minorPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    final majorPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.22)
      ..strokeWidth = 0.9;

    int idx = 0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        idx % 2 == 0 ? majorPaint : minorPaint,
      );
      idx++;
    }
    idx = 0;
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        idx % 2 == 0 ? majorPaint : minorPaint,
      );
      idx++;
    }
  }

  @override
  bool shouldRepaint(covariant _MillimeterGridPainter old) =>
      old.widthMm != widthMm ||
      old.heightMm != heightMm ||
      old.gridMm != gridMm ||
      old.scale != scale;
}
