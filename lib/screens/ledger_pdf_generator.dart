import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/schema.dart';

Future<Uint8List> generateLedgerPdf(Party customer, List<Transaction> history) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("HAMII MOBILES", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text("Account Statement", style: pw.TextStyle(fontSize: 18)),
              ],
            ),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Party Name: ${customer.name}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Phone: ${customer.phone}"),
              ]),
              pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}"),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Date', 'Description', 'Debit (+)', 'Credit (-)'],
            data: history.map((t) {
              // Logic: If it's a payment/income, it reduces balance (Credit)
              bool isCredit = t.type.contains("PAYMENT") || t.type == "PAYMENT_IN";
              return [
                DateFormat('dd-MM-yyyy').format(t.date),
                t.description ?? "-",
                isCredit ? "" : t.amount.toInt().toString(), // Debit (Debt increased)
                isCredit ? t.amount.toInt().toString() : "", // Credit (Paid)
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Net Balance: Rs ${customer.balance.toInt()}",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}