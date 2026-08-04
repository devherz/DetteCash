import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/commerce.dart';
import '../models/client.dart';
import '../models/transaction.dart';

class PdfHelper {
  static final dateFormatter = DateFormat('dd/MM/yyyy à HH:mm');

  /// Formats currency to standard ASCII text (no non-breaking spaces)
  static String formatCurrency(double amount) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final formatted = fmt.format(amount).replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');
    return '$formatted FCFA';
  }

  /// Sanitizes text to remove non-Latin1 / unsupported Unicode characters for Helvetica
  static String sanitize(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('\u202f', ' ') // Narrow non-breaking space
        .replaceAll('\u00a0', ' ') // Non-breaking space
        .replaceAll('’', "'")     // Curly apostrophe
        .replaceAll('‘', "'")
        .replaceAll('”', '"')
        .replaceAll('“', '"')
        .replaceAll('–', '-')      // En-dash
        .replaceAll('—', '-');     // Em-dash
  }

  /// Helper to load a MemoryImage.
  static Future<pw.MemoryImage?> _loadImageFromFile(String? path) async {
    if (path == null) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Helper to load asset logo.
  static Future<pw.MemoryImage?> _loadDetteCashLogo() async {
    try {
      final ByteData logoData = await rootBundle.load('assets/dettecash_logo.jpg');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      return pw.MemoryImage(logoBytes);
    } catch (_) {}
    return null;
  }

  /// Generates a PDF representing the account statement for a client.
  static Future<Uint8List> generateAccountStatementPdf(
    Commerce commerce,
    Client client,
    List<TransactionModel> transactions,
  ) async {
    final pdf = pw.Document();

    // Load logos
    final dcLogo = await _loadDetteCashLogo();
    final shopLogo = await _loadImageFromFile(commerce.logoPath);

    // Calculate totals
    double totalDette = 0.0;
    double totalPaiement = 0.0;
    for (var tx in transactions) {
      if (tx.typeTransaction == TransactionType.dette) {
        totalDette += tx.montant;
      } else {
        totalPaiement += tx.montant;
      }
    }
    final double soldeDue = totalDette - totalPaiement;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: DetteCash Logo
                if (dcLogo != null)
                  pw.Container(
                    width: 70,
                    height: 70,
                    child: pw.Image(dcLogo),
                  )
                else
                  pw.Text('DetteCash', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),

                // Right: Merchant details & Merchant logo
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(sanitize(commerce.nomCommerce), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
                        pw.Text(sanitize('Tél: ${commerce.telephoneCommerce}'), style: const pw.TextStyle(fontSize: 10)),
                        if (commerce.adresseCommerce != null)
                          pw.Text(sanitize(commerce.adresseCommerce!), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (shopLogo != null) ...[
                      pw.SizedBox(width: 10),
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Image(shopLogo),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1, color: PdfColors.grey300),

            // DOCUMENT TITLE
            pw.Center(
              child: pw.Text(
                'RELEVÉ DE COMPTE CLIENT',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, decoration: pw.TextDecoration.underline),
              ),
            ),
            pw.SizedBox(height: 20),

            // CLIENT INFO
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        text: 'Client : ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        children: [
                          pw.TextSpan(text: sanitize(client.nomComplet), style: pw.TextStyle(fontWeight: pw.FontWeight.normal)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.RichText(
                      text: pw.TextSpan(
                        text: 'Téléphone : ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        children: [
                          pw.TextSpan(text: sanitize(client.telephone), style: pw.TextStyle(fontWeight: pw.FontWeight.normal)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  sanitize('Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // SUMMARY CARDS (KPIs)
            pw.Row(
              children: [
                _buildSummaryBox('Total Dettes', formatCurrency(totalDette), PdfColors.red900),
                pw.SizedBox(width: 12),
                _buildSummaryBox('Total Paiements', formatCurrency(totalPaiement), PdfColors.green900),
                pw.SizedBox(width: 12),
                _buildSummaryBox(
                  soldeDue > 0 ? 'Solde Restant Dû' : 'Solde Créditeur',
                  formatCurrency(soldeDue.abs()),
                  soldeDue > 0 ? PdfColors.red900 : PdfColors.green900,
                  isBold: true,
                ),
              ],
            ),
            if (soldeDue <= 0) ...[
              pw.SizedBox(height: 15),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'STATUT : COMPTE ENTIÈREMENT SOLDÉ / EN RÈGLE',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.green900,
                    ),
                  ),
                ),
              ),
            ],
            pw.SizedBox(height: 30),

            // TRANSACTIONS TABLE
            pw.Text(
              'Historique des Opérations',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(110),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(100),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCell('Date', isHeader: true),
                    _buildCell('Description', isHeader: true),
                    _buildCell('Type', isHeader: true),
                    _buildCell('Montant', isHeader: true, alignRight: true),
                  ],
                ),
                // Table Rows
                ...transactions.map((tx) {
                  final isDette = tx.typeTransaction == TransactionType.dette;
                  final typeLabel = isDette ? 'DETTE' : 'PAIEMENT';
                  final typeColor = isDette ? PdfColors.red900 : PdfColors.green900;
                  final descText = tx.description ?? (isDette ? 'Achat à crédit' : 'Règlement');
                  
                  // Appending parent debt details if payment is linked
                  String fullDesc = descText;
                  if (isDette) {
                    final double rem = tx.remainingAmount ?? tx.montant;
                    if (rem <= 0) {
                      fullDesc += ' [SOLDÉE]';
                    } else if (rem < tx.montant) {
                      fullDesc += ' [Reste : ${formatCurrency(rem)}]';
                    }
                  } else if (tx.parentTransactionId != null) {
                    try {
                      final parentTx = transactions.firstWhere((t) => t.id == tx.parentTransactionId);
                      fullDesc += ' (Pour : ${parentTx.description ?? 'Achat'})';
                    } catch (_) {}
                  }

                  return pw.TableRow(
                    children: [
                      _buildCell(sanitize(dateFormatter.format(tx.dateTransaction))),
                      _buildCell(sanitize(fullDesc)),
                      _buildCell(typeLabel, textColor: typeColor, isBold: true),
                      _buildCell(formatCurrency(tx.montant), alignRight: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Généré via DetteCash (version 1.0.0 by Grimm) - Simple. Hors-ligne. Efficace.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a PDF representing a single transaction invoice or receipt.
  static Future<Uint8List> generateTransactionReceiptPdf(
    Commerce commerce,
    Client client,
    TransactionModel transaction, [
    TransactionModel? parentDette,
  ]) async {
    final pdf = pw.Document();

    // Load logos
    final dcLogo = await _loadDetteCashLogo();
    final shopLogo = await _loadImageFromFile(commerce.logoPath);

    final isDette = transaction.typeTransaction == TransactionType.dette;
    final double rem = transaction.remainingAmount ?? transaction.montant;
    final bool isFullyPaid = isDette && rem <= 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // HEADER WITH BOTH LOGOS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (dcLogo != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(dcLogo),
                    )
                  else
                    pw.Text('DetteCash', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(sanitize(commerce.nomCommerce), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.Text(sanitize('MM : ${commerce.telephoneCommerce}'), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),

                  if (shopLogo != null)
                    pw.Container(
                      width: 40,
                      height: 40,
                      child: pw.Image(shopLogo),
                    ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // DOCUMENT TITLE
              pw.Center(
                child: pw.Text(
                  isDette 
                      ? (isFullyPaid ? 'FACTURE DE CRÉANCE (SOLDÉE)' : 'FACTURE DE CRÉANCE (ACHAT)')
                      : 'REÇU DE PAIEMENT',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    color: isDette 
                        ? (isFullyPaid ? PdfColors.green900 : PdfColors.red900) 
                        : PdfColors.green900,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),

              // DETAILS CONTAINER
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildRowDetail('Reçu N° :', '${transaction.id ?? "N/A"}'),
                    _buildRowDetail('Date :', sanitize(dateFormatter.format(transaction.dateTransaction))),
                    _buildRowDetail('Client :', sanitize(client.nomComplet)),
                    _buildRowDetail('Téléphone :', sanitize(client.telephone)),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    _buildRowDetail(
                      isDette ? 'Achat :' : 'Description :',
                      sanitize(transaction.description ?? (isDette ? 'Achat à crédit' : 'Règlement de compte')),
                    ),
                    if (isDette) ...[
                      pw.SizedBox(height: 4),
                      _buildRowDetail(
                        'Statut de la dette :',
                        isFullyPaid
                            ? 'SOLDÉE (Entièrement payée)'
                            : (rem < transaction.montant
                                ? 'EN COURS (Reste : ${formatCurrency(rem)})'
                                : 'NON DÉBUTÉ (Reste : ${formatCurrency(transaction.montant)})'),
                      ),
                    ],
                    if (!isDette && parentDette != null) ...[
                      _buildRowDetail(
                        'Imputé sur :',
                        sanitize(parentDette.description ?? 'Achat du ${DateFormat('dd/MM/yyyy').format(parentDette.dateTransaction)}'),
                      ),
                      pw.SizedBox(height: 4),
                      _buildRowDetail(
                        'Statut de la dette :',
                        (parentDette.remainingAmount ?? parentDette.montant) <= 0
                            ? 'SOLDÉE (Entièrement payée)'
                            : 'EN COURS (Reste : ${formatCurrency(parentDette.remainingAmount ?? parentDette.montant)})',
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // AMOUNT BOX
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: pw.BoxDecoration(
                  color: isDette ? PdfColors.red50 : PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: isDette ? PdfColors.red200 : PdfColors.green200, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'MONTANT :',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: isDette ? PdfColors.red900 : PdfColors.green900),
                    ),
                    pw.Text(
                      formatCurrency(transaction.montant),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                        color: isDette ? PdfColors.red900 : PdfColors.green900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // SIGNATURES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Le Commerçant', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.SizedBox(height: 30),
                      pw.Container(width: 80, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed)))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Le Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.SizedBox(height: 30),
                      pw.Container(width: 80, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed)))),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),

              // FOOTER
              pw.Center(
                child: pw.Text(
                  'DetteCash - version 1.0.0 by Grimm',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a thermal receipt PDF formatted for 80mm Bluetooth/USB POS printers.
  static Future<Uint8List> generateThermalReceiptPdf(
    Commerce commerce,
    Client client,
    TransactionModel transaction, [
    TransactionModel? parentDette,
  ]) async {
    final pdf = pw.Document();

    final dcLogo = await _loadDetteCashLogo();
    final isDette = transaction.typeTransaction == TransactionType.dette;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 180 * PdfPageFormat.mm, marginAll: 8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (dcLogo != null)
                pw.Container(width: 40, height: 40, child: pw.Image(dcLogo)),
              pw.SizedBox(height: 4),
              pw.Text(sanitize(commerce.nomCommerce), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(sanitize('Tél: ${commerce.telephoneCommerce}'), style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Center(
                  child: pw.Text(
                    isDette ? 'FACTURE CREDIT' : 'RECU PAIEMENT',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(sanitize('Date: ${dateFormatter.format(transaction.dateTransaction)}'), style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(sanitize('Client: ${client.nomComplet}'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text(sanitize('Tél Client: ${client.telephone}'), style: const pw.TextStyle(fontSize: 8)),
                    if (transaction.description != null)
                      pw.Text(sanitize('Détails: ${transaction.description!}'), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('MONTANT TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(formatCurrency(transaction.montant), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 12),
              pw.Text('Merci pour votre confiance !', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('DetteCash v1.0.0 by Grimm', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // UI Helpers for PDF building
  static pw.Widget _buildSummaryBox(String label, String value, PdfColor color, {bool isBold = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false, bool alignRight = false, PdfColor? textColor, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  static pw.Widget _buildRowDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
