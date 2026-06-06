import 'package:flutter/material.dart';
import '../models/compare.dart';
import '../core/theme/app_theme.dart';

/// 可展开的对比表格组件 - 每行点击显示详细分析
class CompareTableWidget extends StatefulWidget {
  final CompareTable table;

  const CompareTableWidget({super.key, required this.table});

  @override
  State<CompareTableWidget> createState() => _CompareTableWidgetState();
}

class _CompareTableWidgetState extends State<CompareTableWidget> {
  final Set<int> _expandedRows = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.primary),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          horizontalMargin: 16,
          columnSpacing: 24,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 120,
          columns: widget.table.headers
              .map((h) => DataColumn(label: Text(h, style: const TextStyle(color: Colors.white))))
              .toList(),
          rows: widget.table.rows.asMap().entries.expand((entry) {
            final i = entry.key;
            final row = entry.value;
            final isEven = i.isEven;
            final isExpanded = _expandedRows.contains(i);

            final mainRow = DataRow(
              color: WidgetStateProperty.all(isEven ? Colors.white : AppTheme.background),
              onSelectChanged: row.detail.isEmpty
                  ? null
                  : (_) => setState(() {
                        if (isExpanded) {
                          _expandedRows.remove(i);
                        } else {
                          _expandedRows.add(i);
                        }
                      }),
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (row.detail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: AppTheme.primary.withAlpha(180),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          row.dimension,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                ...row.values.map(
                  (v) => DataCell(
                    SizedBox(
                      width: 140,
                      child: Text(v, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ),
                ),
              ],
            );

            if (!isExpanded) return [mainRow];

            // 展开的详情行
            final detailRow = DataRow(
              color: WidgetStateProperty.all(isEven ? AppTheme.background : Colors.white),
              cells: [
                DataCell(Container()),
                DataCell(
                  Container(
                    width: 280,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppTheme.horizonGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            row.detail,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            return [mainRow, detailRow];
          }).toList(),
        ),
      ),
    );
  }
}
