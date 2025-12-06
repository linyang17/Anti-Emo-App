import Foundation

struct TaskHistoryRecord: Codable, Sendable {
        let id: UUID
        let title: String
        let category: String
        let status: String
        let weather: String
        let energyReward: Int
        let date: Date
        let completedAt: Date?
        let isArchived: Bool
        let isOnboarding: Bool
}

struct MoodHistoryRecord: Codable, Sendable {
        let id: UUID
        let date: Date
        let value: Int
        let source: String
        let delta: Int?
        let relatedTaskCategory: String?
        let relatedWeather: String?
}

struct EnergyEventRecord: Codable, Sendable {
        let id: UUID
        let date: Date
        let delta: Int
        let relatedTaskId: UUID?
}

struct TaskHistoryExport: Codable, Sendable {
        let exportedAt: Date
        let rangeStart: Date
        let rangeEnd: Date
        let tasks: [TaskHistoryRecord]
        let moods: [MoodHistoryRecord]
        let energyEvents: [EnergyEventRecord]
}

private struct ExcelWorksheet {
        let name: String
        let headers: [String]
        let rows: [[String]]
}

struct HistoryExportService {
        private let dateFormatter: ISO8601DateFormatter = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
        }()

        func export(tasks: [UserTask], moods: [MoodEntry], energyEvents: [EnergyEvent], range: ClosedRange<Date>) throws -> URL {
                let taskRecords = tasks.map { task in
                        TaskHistoryRecord(
                                id: task.id,
                                title: task.title,
                                category: task.category.rawValue,
                                status: task.status.rawValue,
                                weather: task.weatherType.rawValue,
                                energyReward: task.energyReward,
                                date: task.date,
                                completedAt: task.completedAt,
                                isArchived: task.isArchived,
                                isOnboarding: task.isOnboarding
                        )
                }

                let moodRecords = moods.map { mood in
                        MoodHistoryRecord(
                                id: mood.id,
                                date: mood.date,
                                value: mood.value,
                                source: mood.source,
                                delta: mood.delta,
                                relatedTaskCategory: mood.relatedTaskCategory,
                                relatedWeather: mood.relatedWeather
                        )
                }

                let energyRecords = energyEvents.map { event in
                        EnergyEventRecord(
                                id: event.id,
                                date: event.date,
                                delta: event.delta,
                                relatedTaskId: event.relatedTaskId
                        )
                }

                let sheets = [
                        ExcelWorksheet(
                                name: "Tasks",
                                headers: ["id", "title", "category", "status", "weather", "energyReward", "date", "completedAt", "isArchived", "isOnboarding"],
                                rows: taskRecords.map { task in
                                        [
                                                task.id.uuidString,
                                                task.title,
                                                task.category,
                                                task.status,
                                                task.weather,
                                                String(task.energyReward),
                                                dateFormatter.string(from: task.date),
                                                task.completedAt.map { dateFormatter.string(from: $0) } ?? "",
                                                String(task.isArchived),
                                                String(task.isOnboarding)
                                        ]
                                }
                        ),
                        ExcelWorksheet(
                                name: "Moods",
                                headers: ["id", "date", "value", "source", "delta", "relatedTaskCategory", "relatedWeather"],
                                rows: moodRecords.map { mood in
                                        [
                                                mood.id.uuidString,
                                                dateFormatter.string(from: mood.date),
                                                String(mood.value),
                                                mood.source,
                                                mood.delta.map(String.init) ?? "",
                                                mood.relatedTaskCategory ?? "",
                                                mood.relatedWeather ?? ""
                                        ]
                                }
                        ),
                        ExcelWorksheet(
                                name: "EnergyEvents",
                                headers: ["id", "date", "delta", "relatedTaskId"],
                                rows: energyRecords.map { event in
                                        [
                                                event.id.uuidString,
                                                dateFormatter.string(from: event.date),
                                                String(event.delta),
                                                event.relatedTaskId?.uuidString ?? ""
                                        ]
                                }
                        )
                ]

                let workbook = ExcelWorkbookBuilder().buildWorkbook(sheets: sheets)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                let filename = "lumio_history_\(formatter.string(from: range.lowerBound))_to_\(formatter.string(from: range.upperBound)).xls"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try workbook.write(to: url, atomically: true, encoding: .utf8)
                return url
        }

        func importHistory(from url: URL) throws -> TaskHistoryExport {
                let parsedSheets = try WorkbookParser().parseWorkbook(at: url)
                guard let taskSheet = parsedSheets["Tasks"], let moodSheet = parsedSheets["Moods"], let energySheet = parsedSheets["EnergyEvents"] else {
                        throw HistoryImportError.missingSheets
                }

                let tasks = parseTaskSheet(taskSheet)
                let moods = parseMoodSheet(moodSheet)
                let events = parseEnergySheet(energySheet)

                let exportedAt = Date()
                let rangeStart = tasks.map(\.date).min() ?? exportedAt
                let rangeEnd = tasks.map(\.date).max() ?? exportedAt

                return TaskHistoryExport(
                        exportedAt: exportedAt,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        tasks: tasks,
                        moods: moods,
                        energyEvents: events
                )
        }

        private func parseTaskSheet(_ sheet: ParsedWorksheet) -> [TaskHistoryRecord] {
                guard let idIndex = sheet.headers.firstIndex(of: "id") else { return [] }
                let lookup: [String: Int] = Dictionary(uniqueKeysWithValues: sheet.headers.enumerated().map { ($1, $0) })

                return sheet.rows.compactMap { row -> TaskHistoryRecord? in
                        // Ensure the row has at least the id column
                        guard row.count > idIndex else { return nil }

                        // Safely parse optional completedAt date
                        let completed: Date?
                        if let completedString = row[safe: lookup["completedAt"]], let date = dateFormatter.date(from: completedString) {
                                completed = date
                        } else {
                                completed = nil
                        }

                        // Build the record using safe lookups and sensible defaults
                        return TaskHistoryRecord(
                                id: UUID(uuidString: row[idIndex]) ?? UUID(),
                                title: row[safe: lookup["title"]] ?? "",
                                category: row[safe: lookup["category"]] ?? "indoorDigital",
                                status: row[safe: lookup["status"]] ?? "pending",
                                weather: row[safe: lookup["weather"]] ?? "sunny",
                                energyReward: Int(row[safe: lookup["energyReward"]] ?? "0") ?? 0,
                                date: row[safe: lookup["date"]].flatMap(dateFormatter.date(from:)) ?? Date(),
                                completedAt: completed,
                                isArchived: Bool(row[safe: lookup["isArchived"]] ?? "false") ?? false,
                                isOnboarding: Bool(row[safe: lookup["isOnboarding"]] ?? "false") ?? false
                        )
                }
        }

        private func parseMoodSheet(_ sheet: ParsedWorksheet) -> [MoodHistoryRecord] {
                let lookup: [String: Int] = Dictionary(uniqueKeysWithValues: sheet.headers.enumerated().map { ($1, $0) })
                return sheet.rows.compactMap { row in
                        guard let id = UUID(uuidString: row[safe: lookup["id"]] ?? "") else { return nil }
                        let date = row[safe: lookup["date"]].flatMap(dateFormatter.date(from:)) ?? Date()
                        return MoodHistoryRecord(
                                id: id,
                                date: date,
                                value: Int(row[safe: lookup["value"]] ?? "0") ?? 0,
                                source: row[safe: lookup["source"]] ?? "",
                                delta: Int(row[safe: lookup["delta"]] ?? ""),
                                relatedTaskCategory: row[safe: lookup["relatedTaskCategory"]],
                                relatedWeather: row[safe: lookup["relatedWeather"]]
                        )
                }
        }

        private func parseEnergySheet(_ sheet: ParsedWorksheet) -> [EnergyEventRecord] {
                let lookup: [String: Int] = Dictionary(uniqueKeysWithValues: sheet.headers.enumerated().map { ($1, $0) })
                return sheet.rows.compactMap { row in
                        guard let id = UUID(uuidString: row[safe: lookup["id"]] ?? "") else { return nil }
                        let date = row[safe: lookup["date"]].flatMap(dateFormatter.date(from:)) ?? Date()
                        let related = row[safe: lookup["relatedTaskId"]].flatMap(UUID.init(uuidString:))
                        return EnergyEventRecord(
                                id: id,
                                date: date,
                                delta: Int(row[safe: lookup["delta"]] ?? "0") ?? 0,
                                relatedTaskId: related
                        )
                }
        }
}

private struct ExcelWorkbookBuilder {
        func buildWorkbook(sheets: [ExcelWorksheet]) -> String {
                let header = "<?xml version=\"1.0\"?>\n<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">"
                let body = sheets.map(makeWorksheet).joined(separator: "\n")
                let footer = "</Workbook>"
                return header + body + footer
        }

        private func makeWorksheet(_ sheet: ExcelWorksheet) -> String {
                let headerRow = sheet.headers.map(cell).joined()
                let rows = sheet.rows.map { row in
                        "<Row>" + row.map(cell).joined() + "</Row>"
                }.joined()

                return "<Worksheet ss:Name=\"\(escape(sheet.name))\"><Table><Row>\(headerRow)</Row>\(rows)</Table></Worksheet>"
        }

        private func cell(_ value: String) -> String {
                "<Cell><Data ss:Type=\"String\">\(escape(value))</Data></Cell>"
        }

        private func escape(_ value: String) -> String {
                value
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                        .replacingOccurrences(of: "\"", with: "&quot;")
                        .replacingOccurrences(of: "'", with: "&apos;")
        }
}

private struct ParsedWorksheet {
        let headers: [String]
        let rows: [[String]]
}

private enum HistoryImportError: Error {
        case missingSheets
}

private final class WorkbookParser: NSObject, XMLParserDelegate {
        private var sheets: [String: ParsedWorksheet] = [:]
        private var currentSheet: String?
        private var currentHeaders: [String] = []
        private var currentRows: [[String]] = []
        private var currentRow: [String] = []
        private var currentCellContent: String = ""
        private var isInHeaderRow = true

        func parseWorkbook(at url: URL) throws -> [String: ParsedWorksheet] {
                let parser = XMLParser(contentsOf: url)
                parser?.delegate = self
                guard parser?.parse() == true else { throw parser?.parserError ?? HistoryImportError.missingSheets }
                return sheets
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                switch elementName {
                case "Worksheet":
                        currentSheet = attributeDict["ss:Name"] ?? attributeDict["Name"]
                        currentHeaders = []
                        currentRows = []
                        isInHeaderRow = true
                case "Row":
                        currentRow = []
                case "Data":
                        currentCellContent = ""
                default:
                        break
                }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
                currentCellContent.append(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                switch elementName {
                case "Data":
                        currentRow.append(currentCellContent.trimmingCharacters(in: .whitespacesAndNewlines))
                case "Row":
                        if isInHeaderRow {
                                currentHeaders = currentRow
                                isInHeaderRow = false
                        } else {
                                currentRows.append(currentRow)
                        }
                case "Worksheet":
                        if let name = currentSheet {
                                sheets[name] = ParsedWorksheet(headers: currentHeaders, rows: currentRows)
                        }
                        currentSheet = nil
                default:
                        break
                }
        }
}

private extension Array where Element == String {
        subscript(safe index: Int?) -> String? {
                guard let index, indices.contains(index) else { return nil }
                return self[index]
        }
}
