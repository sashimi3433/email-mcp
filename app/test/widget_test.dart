import 'package:flutter_test/flutter_test.dart';
import 'package:email_mcp_app/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const EmailMcpApp());
    expect(find.text('Email MCP'), findsOneWidget);
  });
}
