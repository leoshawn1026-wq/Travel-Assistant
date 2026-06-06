import 'package:flutter_test/flutter_test.dart';
import 'package:travel_assistant/app.dart';

void main() {
  testWidgets('App launches with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelApp());

    // Verify the three bottom nav tabs exist
    expect(find.text('AI对话'), findsOneWidget);
    expect(find.text('目的地对比'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
  });
}
