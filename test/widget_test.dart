import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:im_ur_biny_app/app.dart';

void main() {
  testWidgets('App renders idle screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TrashScanApp()));

    // Verify the idle screen headline is present
    expect(find.text("Selamat Datang!"), findsOneWidget);

    // Verify CTA chip is present
    expect(find.text("Sentuh layar untuk mulai"), findsOneWidget);
  });
}
