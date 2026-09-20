/// Receipt text to try the reader on, in the shapes Philippine paper takes.
///
/// EVERY ONE IS LABELLED A SAMPLE and nothing ever falls back to one. That
/// sentence is the whole design, and it is the difference between this file
/// and the prototype's.
///
/// `parseReceiptImage` in src/utils/receiptOcrParser.ts reads the FILE NAME
/// of the picture, matches it against six canned receipts, and returns the
/// Jollibee one when nothing matches. It never opens the image. So
/// photographing a Mercury Drug receipt and letting the camera name it
/// `IMG_4021.jpg` produces a Jollibee purchase carrying a merchant, an
/// amount, a date and a TIN, none of which came from the paper. With the BIR
/// fields now on a transaction, that is somebody else's taxpayer number
/// written into a row the owner may later claim.
///
/// Here they are chosen by tapping a named chip, they say what they are on
/// screen, and the reader treats their text exactly as it treats text from
/// anywhere else. That makes them a demonstration and a test fixture rather
/// than a fabrication.
library;

class ReceiptSample {
  const ReceiptSample({
    required this.label,
    required this.text,
    required this.note,
  });

  /// What the chip says.
  final String label;

  /// The recognised text, as a camera would hand it over.
  final String text;

  /// What this one is here to show.
  final String note;
}

const List<ReceiptSample> receiptSamples = <ReceiptSample>[
  ReceiptSample(
    label: 'Jollibee',
    note: 'An official receipt, with a TIN, so the BIR fields fill in.',
    text: '''
JOLLIBEE FOODS CORPORATION
Jollibee Ayala Triangle
VAT REG TIN: 000-408-495-000
OFFICIAL RECEIPT
OR No. 0084512

1 Chickenjoy w/ Rice        99.00
1 Jolly Spaghetti           69.00
1 Peach Mango Pie           45.00

VATable Sale              190.18
VAT 12%                    22.82
TOTAL AMOUNT DUE          213.00
CASH TENDERED             500.00
SUKLI                     287.00

20 Sep 2026  14:32
Thank you and come again!
''',
  ),
  ReceiptSample(
    label: 'Puregold',
    note:
        'A grocery slip. Several items, and a change line bigger than the '
        'total.',
    text: '''
PUREGOLD PRICE CLUB INC
Shaw Boulevard Branch
VAT REG TIN 201-233-000-00000

Bear Brand Powder 1.2kg     489.75
Lucky Me Pancit Canton      108.00
Century Tuna Flakes         142.50
Kopiko Brown 3in1            95.25
Tide Powder 2kg             318.00

SUBTOTAL                   1153.50
TOTAL                      1153.50
CASH                       2000.00
CHANGE                      846.50

09/20/2026
''',
  ),
  ReceiptSample(
    label: '7-Eleven',
    note: 'A thermal POS slip with no clean total label.',
    text: '''
PHILIPPINE SEVEN CORPORATION
7-ELEVEN BGC STOPOVER
TIN 000-166-735-000

Gardenia Loaf              PHP 72.00
Coke Zero 500ml            PHP 45.00
Piattos Cheese             PHP 28.00

AMOUNT DUE                 PHP 145.00

2026-09-20
''',
  ),
  ReceiptSample(
    label: 'GCash send',
    note: 'An e-wallet screenshot. No merchant, no TIN, and an account hint.',
    text: '''
GCash
Express Send

Amount Sent
PHP 2,500.00

Send to
JUAN D. DELA CRUZ
0917*****234

Reference No. 1029384756123
Sep 20, 2026 09:14 AM
''',
  ),
  ReceiptSample(
    label: 'GrabCar',
    note: 'A ride, paid by card. The word "grab" must not file it as food.',
    text: '''
Grab Philippines
GrabCar Receipt

Trip fare                   PHP 268.00
Platform fee                 PHP 12.00
TOTAL                       PHP 280.00

Paid with Maya card ending 4402
Ref: GRB-20260920-88412
20/09/2026
''',
  ),
  ReceiptSample(
    label: 'Mercury Drug',
    note: 'A pharmacy official receipt with maintenance medicine.',
    text: '''
MERCURY DRUG CORPORATION
Katipunan Branch
VAT REG TIN: 000-165-411-000
OFFICIAL RECEIPT

Losartan 50mg x30           540.00
Metformin 500mg x30         285.00
Biogesic 500mg x10           78.00

TOTAL AMOUNT DUE            903.00

Sep 20, 2026
''',
  ),
];
