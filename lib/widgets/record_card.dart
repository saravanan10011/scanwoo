import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import '../services/models/scan_record.dart';
import '../utils/helpers.dart';

// Same 375x812 baseline scaling used across the app's screens, kept
// private to this file so RecordCard stays a drop-in, self-contained
// widget wherever it's used.

class RecordCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RecordCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  String get _title {
    if (record.text.trim().isEmpty) return 'Untitled scan';
    return record.text.trim().split('\n').first;
  }

  String? get _preview {
    final lines = record.text.trim().split('\n');
    if (lines.length < 2) return null;
    final rest = lines.sublist(1).join(' ').trim();
    return rest.isEmpty ? null : rest;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(Sizes.w(16)),
        border: Border.all(color: ColorConstants.surfaceGray2),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(Sizes.w(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: Sizes.w(46),
              height: Sizes.w(46),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ColorConstants.primarySoft,
                    primaryColor.withValues(alpha: 0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(Sizes.w(14)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.description_outlined,
                color: primaryColor,
                size: Sizes.w(22),
              ),
            ),
            SizedBox(width: Sizes.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: Sizes.sp(14),
                      color: ColorConstants.textDark,
                    ),
                  ),
                  if (_preview != null) ...[
                    SizedBox(height: Sizes.w(3)),
                    Text(
                      _preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Sizes.sp(12),
                        color: ColorConstants.textMuted,
                      ),
                    ),
                  ],
                  SizedBox(height: Sizes.w(6)),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: Sizes.w(13),
                        color: ColorConstants.textMuted,
                      ),
                      SizedBox(width: Sizes.w(4)),
                      Text(
                        formatShortDate(record.createdAt),
                        style: TextStyle(
                          fontSize: Sizes.sp(11.5),
                          color: ColorConstants.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _menuButton(context),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: ColorConstants.textMuted,
        size: Sizes.w(20),
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.w(14)),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: ColorConstants.textDark,
                  ),
                  SizedBox(width: Sizes.w(10)),
                  const Text(
                    'Edit',
                    style: TextStyle(color: ColorConstants.textDark),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: ColorConstants.redAccent,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Delete',
                    style: TextStyle(color: ColorConstants.redAccent),
                  ),
                ],
              ),
            ),
          ],
    );
  }
}
