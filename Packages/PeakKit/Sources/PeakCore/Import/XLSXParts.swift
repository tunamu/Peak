import Foundation

/// The XML parts of a one-sheet .xlsx workbook, as small as Excel, Numbers and Google Sheets accept.
enum XLSXParts {
    enum Cell {
        case text(String, style: Int = 0)
        case number(Double, style: Int = 0)
    }

    private static let main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relations = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let packageRelations = "http://schemas.openxmlformats.org/package/2006/relationships"
    private static let prolog = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

    static let contentTypes =
        prolog + #"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
        + #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#
        + #"<Default Extension="xml" ContentType="application/xml"/>"#
        + #"<Override PartName="/xl/workbook.xml" "#
        + #"ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>"#
        + #"<Override PartName="/xl/worksheets/sheet1.xml" "#
        + #"ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        + #"<Override PartName="/xl/styles.xml" "#
        + #"ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>"#
        + "</Types>"

    static let rootRelations =
        prolog + #"<Relationships xmlns="\#(packageRelations)">"#
        + #"<Relationship Id="rId1" Type="\#(relations)/officeDocument" Target="xl/workbook.xml"/>"#
        + "</Relationships>"

    static let workbookRelations =
        prolog + #"<Relationships xmlns="\#(packageRelations)">"#
        + #"<Relationship Id="rId1" Type="\#(relations)/worksheet" Target="worksheets/sheet1.xml"/>"#
        + #"<Relationship Id="rId2" Type="\#(relations)/styles" Target="styles.xml"/>"#
        + "</Relationships>"

    /// Styles: 0 plain, 1 bold, 2 the locale's short date (built-in format 14).
    static let styles =
        prolog + #"<styleSheet xmlns="\#(main)">"#
        + #"<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>"#
        + #"<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>"#
        + #"<fills count="2"><fill><patternFill patternType="none"/></fill>"#
        + #"<fill><patternFill patternType="gray125"/></fill></fills>"#
        + #"<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"#
        + #"<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>"#
        + #"<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>"#
        + #"<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>"#
        + #"<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>"#
        + #"<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>"#
        + "</styleSheet>"

    static func workbook(sheetName: String) -> String {
        prolog + #"<workbook xmlns="\#(main)" xmlns:r="\#(relations)">"#
            + #"<sheets><sheet name="\#(escaped(sheetName))" sheetId="1" r:id="rId1"/></sheets></workbook>"#
    }

    /// A sheet with a frozen first row and the given column widths (in characters).
    static func worksheet(rows: [String], widths: [Int]) -> String {
        let columns = widths.enumerated().map { index, width in
            #"<col min="\#(index + 1)" max="\#(index + 1)" width="\#(width)" customWidth="1"/>"#
        }
        return prolog + #"<worksheet xmlns="\#(main)">"#
            + #"<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" state="frozen"/>"#
            + "</sheetView></sheetViews>"
            + "<cols>\(columns.joined())</cols><sheetData>\(rows.joined())</sheetData></worksheet>"
    }

    /// Row `number` (from 1); empty text cells are left out.
    static func row(_ number: Int, _ cells: [Cell]) -> String {
        let xml = cells.enumerated().compactMap { column, cell -> String? in
            let reference = "\(CellName.of(row: number - 1, column: column, sheet: ""))"
            switch cell {
            case .text(let text, _) where text.isEmpty:
                return nil
            case .text(let text, let style):
                return #"<c r="\#(reference)" s="\#(style)" t="inlineStr"><is><t>\#(escaped(text))</t></is></c>"#
            case .number(let value, let style):
                let text = value == value.rounded() ? String(Int(value)) : String(value)
                return #"<c r="\#(reference)" s="\#(style)"><v>\#(text)</v></c>"#
            }
        }
        return #"<row r="\#(number)">\#(xml.joined())</row>"#
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
