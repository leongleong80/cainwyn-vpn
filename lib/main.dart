import 'package:flutter/material.dart';
import 'package:hiddify/bootstrap.dart';
import 'package:hiddify/core/model/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap(Environment.dev);
}
