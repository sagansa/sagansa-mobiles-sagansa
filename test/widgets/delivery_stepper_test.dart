import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagansa/models/enums/delivery_status.dart';
import 'package:sagansa/models/enums/order_mode.dart';
import 'package:sagansa/widgets/delivery/delivery_stepper.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DeliveryStepper', () {
    testWidgets('renders without crashing for online + pending', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.pending,
          orderMode: OrderMode.online,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });

    testWidgets('renders for direct + delivered', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.delivered,
          orderMode: OrderMode.direct,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });

    testWidgets('renders for returned status', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.returned,
          orderMode: OrderMode.online,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });

    testWidgets('cancelled online: langkah terminal jadi Dibatalkan',
        (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.cancelled,
          orderMode: OrderMode.online,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
      // Langkah aktif bukan "Belum Kirim" — terminal "Dibatalkan".
      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('renders for ready status', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.ready,
          orderMode: OrderMode.online,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });

    testWidgets('renders for valid status (locked)', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.valid,
          orderMode: OrderMode.direct,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });

    testWidgets('renders sticker printed indicator', (tester) async {
      await tester.pumpWidget(wrap(
        const DeliveryStepper(
          status: DeliveryStatus.delivered,
          orderMode: OrderMode.online,
          isStickerPrinted: true,
        ),
      ));
      expect(find.byType(DeliveryStepper), findsOneWidget);
    });
  });
}
