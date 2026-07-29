import 'package:flutter/material.dart';

class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;

  // Semantic aliases used by shared widgets and screens
  static const double xs = 4.0;
  static const double sm = small;
  static const double input = medium;
  static const double button = medium;
  static const double card = large;

  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get xlargeRadius => BorderRadius.circular(xlarge);
}
