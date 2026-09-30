#!/usr/bin/env python3
"""Writes the import reader fixtures (F7-04). Run from this folder: python3 make_fixtures.py

The files imitate what spreadsheet apps write: Turkish Excel's CSV (Windows-1254, ';', CRLF, decimal commas) and
.xlsx parts written by hand so every case the reader handles is present (shared and inline strings, rich text,
date formats, formulas, gaps, hidden sheets, namespace prefixes, the 1904 date system).
"""
import zipfile
from datetime import date

# --- CSV / TSV ---------------------------------------------------------------------------------------------------

tr_rows = [
    "Tarih;Hareket;Set;Ağırlık;Tekrar;Not",
    "28.09.2026;Dumbell Chest Press;1;27,5;9;",
    "28.09.2026;Dumbell Chest Press;2;22,5;13;\"Son set; zorlandım\"",
    "",
    "28.09.2026;İncline Dumbell Curl;1;15;9;\"İki\nsatır\"",
    "30.09.2026;Lat Pulldown;1;1.002,5;8;\"Tırnak \"\"içinde\"\"\"",
]
with open("tr-excel.csv", "wb") as f:
    f.write(("\r\n".join(tr_rows) + "\r\n").encode("cp1254"))

utf8_rows = [
    "Date,Exercise,Weight,Reps",
    "2026-09-28,\"Row, seated\",60.5,8",
    "2026-09-28,Lateral Raise,15,12",
]
with open("utf8-bom.csv", "wb") as f:
    f.write(b"\xef\xbb\xbf" + "\n".join(utf8_rows).encode("utf-8"))

with open("sets.tsv", "wb") as f:
    f.write("Hareket\t1. Set\t2. Set\nFly\t50x7\t45x8:9\nRow\t27,5 x 9\t-\n".encode("utf-8"))

# --- XLSX --------------------------------------------------------------------------------------------------------

MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL = "http://schemas.openxmlformats.org/package/2006/relationships"


def serial(d, system1904=False):
    return (d - (date(1904, 1, 1) if system1904 else date(1899, 12, 30))).days


def workbook(path, sheets, shared, styles, date1904=False):
    """sheets: [(name, xml, hidden)]"""
    content_types = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        "</Types>"
    )
    root_rels = (
        f'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="{PKG_REL}">'
        f'<Relationship Id="rId1" Type="{REL}/officeDocument" Target="xl/workbook.xml"/></Relationships>'
    )
    hidden_attribute = ' state="hidden"'
    sheet_list = "".join(
        f'<sheet name="{name}" sheetId="{i + 1}" r:id="rId{i + 1}"{hidden_attribute if hidden else ""}/>'
        for i, (name, _, hidden) in enumerate(sheets)
    )
    pr = '<workbookPr date1904="1"/>' if date1904 else "<workbookPr/>"
    wb = (
        f'<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="{MAIN}" xmlns:r="{REL}">{pr}'
        f"<sheets>{sheet_list}</sheets></workbook>"
    )
    rels = "".join(
        # The first sheet uses an absolute target, the others relative ones: both occur in the wild.
        f'<Relationship Id="rId{i + 1}" Type="{REL}/worksheet" '
        f'Target="{"/xl/" if i == 0 else ""}worksheets/sheet{i + 1}.xml"/>'
        for i in range(len(sheets))
    )
    wb_rels = f'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="{PKG_REL}">{rels}</Relationships>'
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types)
        z.writestr("_rels/.rels", root_rels)
        z.writestr("xl/workbook.xml", wb)
        z.writestr("xl/_rels/workbook.xml.rels", wb_rels)
        if shared is not None:
            z.writestr("xl/sharedStrings.xml", shared)
        if styles is not None:
            z.writestr("xl/styles.xml", styles)
        for i, (_, xml, _) in enumerate(sheets):
            z.writestr(f"xl/worksheets/sheet{i + 1}.xml", xml)


shared = (
    f'<?xml version="1.0" encoding="UTF-8"?><sst xmlns="{MAIN}" count="6" uniqueCount="6">'
    "<si><t>Tarih</t></si>"
    "<si><t>Hareket</t></si>"
    "<si><t>Ağırlık</t></si>"
    "<si><t>Tekrar</t></si>"
    # Rich text in two runs, with a phonetic hint that is not part of the text.
    '<si><r><rPr><b/></rPr><t>Dumbell </t></r><r><t xml:space="preserve">Chest Press</t></r>'
    "<rPh sb=\"0\" eb=\"1\"><t>ダ</t></rPh></si>"
    "<si><t>Saat</t></si>"
    "</sst>"
)
styles = (
    f'<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="{MAIN}">'
    '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd\\.mm\\.yyyy"/>'
    '<numFmt numFmtId="165" formatCode="[$-41F]d&quot; gün &quot;mmmm yyyy;@"/></numFmts>'
    '<cellXfs count="6"><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="14"/><xf numFmtId="20"/>'
    '<xf numFmtId="165"/><xf numFmtId="2"/></cellXfs>'
    "</styleSheet>"
)
d1 = serial(date(2026, 9, 28))
d2 = serial(date(2026, 9, 30))
sheet1 = (
    f'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="{MAIN}"><sheetData>'
    '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c>'
    '<c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>5</v></c></row>'
    # Custom date format, rich text, a weight with a fixed 2-decimal format (not a date), a formula, a time.
    f'<row r="2"><c r="A2" s="1"><v>{d1}</v></c><c r="B2" t="s"><v>4</v></c><c r="C2" s="5"><v>27.5</v></c>'
    '<c r="D2"><f>4+5</f><v>9</v></c><c r="E2" s="3"><v>0.77083333333333337</v></c></row>'
    # Built-in date format, an inline string, a gap in column C, a serial with a time under a date-only format.
    f'<row r="3"><c r="A3" s="2"><v>{d1}.75</v></c><c r="B3" t="inlineStr"><is><t>  Row  </t></is></c>'
    '<c r="D3"><v>13</v></c></row>'
    # Row 4 is missing; row 5 has a Turkish long date, a boolean, an error and an exponent.
    f'<row r="5"><c r="A5" s="4"><v>{d2}</v></c><c r="B5" t="b"><v>1</v></c><c r="C5" t="e"><v>#N/A</v></c>'
    '<c r="D5"><v>1.5E-3</v></c><c r="E5" t="str"><f>"x"</f><v>x</v></c></row>'
    "</sheetData></worksheet>"
)
# A second sheet written with a namespace prefix and without cell references.
sheet2 = (
    f'<?xml version="1.0" encoding="UTF-8"?><x:worksheet xmlns:x="{MAIN}"><x:sheetData>'
    '<x:row><x:c t="inlineStr"><x:is><x:t>Notlar</x:t></x:is></x:c><x:c><x:v>42</x:v></x:c></x:row>'
    "</x:sheetData></x:worksheet>"
)
# A hidden sheet: left out by the reader, since nobody sees it in Excel.
hidden = f'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="{MAIN}"><sheetData><row r="1"><c r="A1"><v>1</v></c></row></sheetData></worksheet>'
workbook(
    "workbook.xlsx",
    [("Antrenman", sheet1, False), ("Gizli", hidden, True), ("Notlar", sheet2, False)],
    shared,
    styles,
)

d1904 = serial(date(2026, 9, 28), system1904=True)
sheet1904 = (
    f'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="{MAIN}"><sheetData>'
    f'<row r="1"><c r="A1" s="1"><v>{d1904}</v></c><c r="B1"><v>60</v></c></row>'
    "</sheetData></worksheet>"
)
workbook("date1904.xlsx", [("Sheet1", sheet1904, False)], None, styles, date1904=True)

with open("not-a-workbook.xlsx", "wb") as f:
    f.write("Tarih;Hareket\r\n".encode("utf-8"))

# --- Layouts (F7-05) ---------------------------------------------------------------------------------------------

# Block: the /coach history as a spreadsheet (an excerpt of the real Antrenman-Gecmisi), a section, then exercises
# with a column-name row and one row per session.
block_rows = [
    ["Antrenman Geçmişi"],
    ["Göğüs (Chest)"],
    ["Dumbell Chest Press"],
    ["Tarih / Seans", "1. Set (Ağırlık x Tekrar)", "2. Set (Ağırlık x Tekrar)", "3. Set (Ağırlık x Tekrar)"],
    ["1. Seans", "22.5 x 9", "17.5 x 10", "-"],
    ["2. Seans", "25 x 7", "20 x 10", "-"],
    ["3. Seans (07.09.2026)", "25 x 9", "22.5 x 8", "-"],
    ["6. Seans (28.09.2026)", "27.5 x 9", "22.5 x 13", "-"],
    [],
    ["İncline Smith Machine Press"],
    ["Tarih / Seans", "1. Set (Ağırlık x Tekrar)", "2. Set (Ağırlık x Tekrar)", "3. Set (Ağırlık x Tekrar)"],
    ["1. Seans", "50 x 4", "40 x 6", "-"],
    ["6. Seans (28.09.2026)", "55 x 6", "45 x 9", "-"],
    [],
    ["Sırt (Back)"],
    ["Lat Pulldown"],
    ["Tarih / Seans", "1. Set (Ağırlık x Tekrar)", "2. Set (Ağırlık x Tekrar)", "3. Set (Ağırlık x Tekrar)"],
    ["1. Seans", "55 x 8", "55 x 8", "-"],
    ["2. Seans (09.09.2026)", "60 x 8", "55 x 9", "-"],
    [],
    # Same day as the chest's "3. Seans", but this exercise's first: one session for that day.
    ["Triceps (Arka Kol)"],
    ["V Bar Triceps Pushdown"],
    ["Tarih / Seans", "1. Set (Ağırlık x Tekrar)", "2. Set (Ağırlık x Tekrar)", "3. Set (Ağırlık x Tekrar)"],
    ["1. Seans (07.09.2026)", "55 x 10", "50 x 12", "-"],
]


def csv_cell(value, delimiter):
    return f'"{value}"' if delimiter in value or '"' in value else value


with open("block.csv", "wb") as f:
    f.write("\r\n".join(";".join(csv_cell(c, ";") for c in row) for row in block_rows).encode("utf-8"))


def column_letter(index):
    letters = ""
    index += 1
    while index:
        index, remainder = divmod(index - 1, 26)
        letters = chr(65 + remainder) + letters
    return letters


def text_sheet(rows):
    """A sheet of inline strings, as some writers (and exports from apps) produce."""
    xml_rows = []
    for r, row in enumerate(rows):
        cells = "".join(
            f'<c r="{column_letter(c)}{r + 1}" t="inlineStr"><is><t>{value}</t></is></c>'
            for c, value in enumerate(row)
            if value
        )
        xml_rows.append(f'<row r="{r + 1}">{cells}</row>')
    return f'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="{MAIN}"><sheetData>{"".join(xml_rows)}</sheetData></worksheet>'


workbook("block.xlsx", [("Geçmiş", text_sheet(block_rows), False)], None, None)

# Wide with weight and reps pairs; the date and workout are written once per session.
with open("wide-pairs.csv", "w", encoding="utf-8") as f:
    f.write(
        "Date,Workout,Exercise,Weight 1,Reps 1,Weight 2,Reps 2\n"
        "2026-09-28,Chest & Biceps,Dumbbell Chest Press,27.5,9,22.5,13\n"
        ",,Incline Dumbbell Curl,15,9,12.5,9\n"
        "2026-09-30,Back & Triceps,Lat Pulldown,60,8,55,9\n"
    )

# Long, American: month first, pounds in the header, a set number column out of order.
with open("us-long.csv", "w", encoding="utf-8") as f:
    f.write(
        "Date,Exercise,Set,Weight (lbs),Reps,Notes\n"
        "9/28/2026,Bench Press,2,135,8,\n"
        "9/28/2026,Bench Press,1,155,5,felt heavy\n"
        "9/30/2026,Squat,1,185,5,\n"
    )

# Dates that fit both orders: the analyzer must not be sure.
with open("ambiguous-dates.csv", "w", encoding="utf-8") as f:
    f.write("Date,Exercise,Weight,Reps\n01/02/2026,Row,60,8\n03/04/2026,Row,60,9\n")

# No header row: the analyzer guesses and is not sure.
with open("no-header.csv", "w", encoding="utf-8") as f:
    f.write("28.09.2026;Row;60x8;55x9\n30.09.2026;Row;60x9;55x10\n")
