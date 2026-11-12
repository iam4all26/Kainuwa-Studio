import 'package:flutter/material.dart';

import '../theme.dart';

class TemplatesTab extends StatelessWidget {
  const TemplatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 56, color: KColors.purple),
              SizedBox(height: 16),
              Text(
                'Templates',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Ready-made slide layouts with a background, text style and icons will appear here once the slide editor is built.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
