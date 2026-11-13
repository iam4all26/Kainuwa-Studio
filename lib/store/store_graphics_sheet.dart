import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'store_service.dart';

/// Shapes and icons downloaded from the store. Returns the chosen item.
Future<InstalledItem?> showStoreGraphicsSheet(BuildContext context) {
  final items = [
    ...StoreService.instance.ofType('shape'),
    ...StoreService.instance.ofType('icon'),
  ];
  return showModalBottomSheet<InstalledItem>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('From the store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Download shapes and icons from the Store tab first.'),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in items)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(sheetContext).pop(item),
                          child: Container(
                            width: 84,
                            height: 84,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: KColors.lavender,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: SvgPicture.file(
                              File(item.path),
                              fit: BoxFit.contain,
                              colorFilter: item.type == 'icon'
                                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
