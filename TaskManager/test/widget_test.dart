import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/main.dart';

void main() {
  testWidgets('TaskManagerApp khởi chạy thành công',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TaskManagerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}