import 'package:flutter/material.dart';

class AppShadows {
  static final List<BoxShadow> sm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    )
  ];

  static final List<BoxShadow> md = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    )
  ];

  static final List<BoxShadow> lg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 8),
    )
  ];
  
  static final List<BoxShadow> hover = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
    )
  ];
}
