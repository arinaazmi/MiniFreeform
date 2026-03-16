//
//  MiniFreeformApp.swift
//
//  A lightweight SwiftUI canvas for simple note taking.
//

import Combine
import SwiftUI

enum CanvasColor: String, Codable, CaseIterable {
    case blue
    case coral
    case gold
    case mint
    case primary

    var swiftUIColor: Color {
        switch self {
        case .blue:
            return Color(red: 0.22, green: 0.48, blue: 0.95)
        case .coral:
            return Color(red: 0.96, green: 0.46, blue: 0.39)
        case .gold:
            return Color(red: 0.89, green: 0.68, blue: 0.20)
        case .mint:
            return Color(red: 0.18, green: 0.68, blue: 0.58)
        case .primary:
            return .primary
        }
    }
}

enum CanvasItem: Identifiable, Codable {
    case rectangle(RectangleItem)
    case freehand(FreehandItem)
    case text(TextItem)

    var id: UUID {
        switch self {
        case .rectangle(let item):
            item.id
        case .freehand(let item):
            item.id
        case .text(let item):
            item.id
        }
    }

    var position: CGPoint {
        get {
            switch self {
            case .rectangle(let item):
                item.position
            case .freehand(let item):
                item.position
            case .text(let item):
                item.position
            }
        }
        set {
            switch self {
            case .rectangle(var item):
                item.position = newValue
                self = .rectangle(item)
            case .freehand(var item):
                item.position = newValue
                self = .freehand(item)
            case .text(var item):
                item.position = newValue
                self = .text(item)
            }
        }
    }

    var displayName: String {
        switch self {
        case .rectangle:
            "Card"
        case .freehand:
            "Stroke"
        case .text:
            "Note"
        }
    }
}

struct RectangleItem: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var color: CanvasColor

    init(id: UUID = UUID(), position: CGPoint, size: CGSize, color: CanvasColor) {
        self.id = id
        self.position = position
        self.size = size
        self.color = color
    }
}

struct FreehandItem: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    var points: [CGPoint]
    var strokeColor: CanvasColor
    var lineWidth: CGFloat

    init(
        id: UUID = UUID(),
        position: CGPoint,
        points: [CGPoint],
        strokeColor: CanvasColor,
        lineWidth: CGFloat
    ) {
        self.id = id
        self.position = position
        self.points = points
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
    }
}

struct TextItem: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    var text: String
    var color: CanvasColor

    init(id: UUID = UUID(), position: CGPoint, text: String, color: CanvasColor) {
        self.id = id
        self.position = position
        self.text = text
        self.color = color
    }
}

@MainActor
final class CanvasViewModel: ObservableObject {
    @Published private(set) var items: [CanvasItem] = []

    private var saveTask: Task<Void, Never>?
    private let saveURL: URL
    private var itemCreationCount = 0

    init(saveURL: URL? = nil, autoload: Bool = true) {
        self.saveURL = saveURL ?? Self.defaultSaveURL

        if autoload {
            Task {
                await load()
            }
        }
    }

    static var defaultSaveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("canvas.json")
    }

    func add(_ item: CanvasItem) {
        items.append(item)
        itemCreationCount += 1
        scheduleSave()
    }

    func updatePosition(of id: UUID, to newPosition: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].position = newPosition
        scheduleSave()
    }

    func updateText(of id: UUID, to newText: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .text(var item) = items[index] else { return }

        item.text = newText
        items[index] = .text(item)
        scheduleSave()
    }

    func bringToFront(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        items.append(item)
        scheduleSave()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }

    func clear() {
        items.removeAll()
        scheduleSave()
    }

    func suggestedPosition(in size: CGSize) -> CGPoint {
        let horizontalSpacing: CGFloat = 36
        let verticalSpacing: CGFloat = 28
        let column = itemCreationCount % 4
        let row = (itemCreationCount / 4) % 4

        let x = min(max(110 + (CGFloat(column) * horizontalSpacing), 90), max(size.width - 90, 90))
        let y = min(max(150 + (CGFloat(row) * verticalSpacing), 120), max(size.height - 160, 120))
        return CGPoint(x: x, y: y)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = items

        saveTask = Task { [saveURL] in
            do {
                try await Task.sleep(for: .seconds(0.5))
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: saveURL, options: .atomic)
            } catch is CancellationError {
                return
            } catch {
                print("Failed to save canvas: \(error)")
            }
        }
    }

    private func load() async {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }

        do {
            let data = try Data(contentsOf: saveURL)
            let decoded = try JSONDecoder().decode([CanvasItem].self, from: data)
            items = decoded
            itemCreationCount = decoded.count
        } catch {
            print("Failed to load canvas: \(error)")
        }
    }
}

private struct ItemMetrics {
    let width: CGFloat
    let height: CGFloat
}

private extension CanvasItem {
    var metrics: ItemMetrics {
        switch self {
        case .rectangle(let item):
            return ItemMetrics(width: item.size.width, height: item.size.height)
        case .freehand(let item):
            let bounds = item.normalizedBounds
            return ItemMetrics(width: max(bounds.width, 44), height: max(bounds.height, 44))
        case .text(let item):
            let estimatedWidth = min(max(CGFloat(item.text.count) * 9 + 44, 110), 240)
            return ItemMetrics(width: estimatedWidth, height: 52)
        }
    }

}

extension CanvasItem {
    var textValue: String? {
        guard case .text(let item) = self else { return nil }
        return item.text
    }
}

private extension FreehandItem {
    var normalizedPoints: [CGPoint] {
        guard let firstPoint = points.first else { return [] }
        return points.map {
            CGPoint(x: $0.x - firstPoint.x, y: $0.y - firstPoint.y)
        }
    }

    var normalizedBounds: CGRect {
        let normalized = normalizedPoints
        guard let firstPoint = normalized.first else { return .zero }

        var minX = firstPoint.x
        var maxX = firstPoint.x
        var minY = firstPoint.y
        var maxY = firstPoint.y

        for point in normalized.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct CanvasItemView: View {
    let item: CanvasItem
    let isSelected: Bool

    var body: some View {
        switch item {
        case .rectangle(let rectangle):
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            rectangle.color.swiftUIColor.opacity(0.95),
                            rectangle.color.swiftUIColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    Image(systemName: "square.grid.2x2")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(14)
                }
                .frame(width: rectangle.size.width, height: rectangle.size.height)
                .shadow(color: rectangle.color.swiftUIColor.opacity(0.25), radius: 20, y: 8)
                .overlay(selectionOutline)
        case .freehand(let freehand):
            let bounds = freehand.normalizedBounds

            Path { path in
                let normalized = freehand.normalizedPoints
                guard let firstPoint = normalized.first else { return }

                path.move(to: CGPoint(x: firstPoint.x - bounds.minX, y: firstPoint.y - bounds.minY))
                for point in normalized.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x - bounds.minX, y: point.y - bounds.minY))
                }
            }
            .stroke(
                freehand.strokeColor.swiftUIColor,
                style: StrokeStyle(lineWidth: freehand.lineWidth, lineCap: .round, lineJoin: .round)
            )
            .padding(18)
            .frame(
                width: max(bounds.width, 44) + 36,
                height: max(bounds.height, 44) + 36,
                alignment: .topLeading
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(selectionOutline)
        case .text(let text):
            Text(text.text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(text.color.swiftUIColor)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 120, maxWidth: 220, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "text.cursor")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
                .overlay(selectionOutline)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var selectionOutline: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 3)
                .padding(-4)
        }
    }
}

private struct CanvasGridBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.99),
                    Color(red: 0.94, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let spacing: CGFloat = 28
                let dotColor = Color.primary.opacity(0.10)

                for x in stride(from: spacing, through: size.width, by: spacing) {
                    for y in stride(from: spacing, through: size.height, by: spacing) {
                        let rect = CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2)
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct EmptyCanvasView: View {
    let addNote: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(18)
                .background(.ultraThinMaterial, in: Circle())

            VStack(spacing: 8) {
                Text("Start a lightweight board")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Add a note, card, or stroke and drag it anywhere. Everything persists automatically.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Button("Add Your First Note", action: addNote)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 30, y: 12)
        .padding(24)
    }
}

private struct CanvasControlBar: View {
    let canEditText: Bool
    let hasSelection: Bool
    let hasItems: Bool
    let addRectangle: () -> Void
    let addFreehand: () -> Void
    let addText: () -> Void
    let editText: () -> Void
    let deleteSelection: () -> Void
    let clearCanvas: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                controlButton("Note", systemImage: "text.badge.plus", action: addText)
                controlButton("Card", systemImage: "square.on.square", action: addRectangle)
                controlButton("Stroke", systemImage: "pencil.tip.crop.circle.badge.plus", action: addFreehand)
            }

            HStack(spacing: 10) {
                controlButton("Edit Text", systemImage: "text.cursor", isEnabled: canEditText, action: editText)
                controlButton("Delete", systemImage: "trash", isEnabled: hasSelection, role: .destructive, action: deleteSelection)
                controlButton("Clear", systemImage: "sparkles.rectangle.stack", isEnabled: hasItems, role: .destructive, action: clearCanvas)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 6)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        isEnabled: Bool = true,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(role == .destructive ? .red : .accentColor)
        .disabled(!isEnabled)
    }
}

struct CanvasView: View {
    @StateObject private var model = CanvasViewModel()
    @State private var selectedItemID: UUID?
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var isEditingText = false
    @State private var isConfirmingClear = false
    @State private var textDraft = ""

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CanvasGridBackground()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItemID = nil
                    }

                if model.items.isEmpty {
                    EmptyCanvasView(addNote: {
                        addText(in: proxy.size)
                    })
                }

                ForEach(model.items) { item in
                    CanvasItemView(item: item, isSelected: item.id == selectedItemID)
                        .position(item.position)
                        .accessibilityIdentifier(accessibilityIdentifier(for: item))
                        .onTapGesture {
                            selectedItemID = item.id
                            model.bringToFront(item.id)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    selectedItemID = item.id
                                    let startPosition = dragStartPositions[item.id] ?? item.position
                                    dragStartPositions[item.id] = startPosition
                                    model.bringToFront(item.id)
                                    model.updatePosition(
                                        of: item.id,
                                        to: clampedPosition(
                                            startPosition,
                                            translation: value.translation,
                                            item: item,
                                            canvasSize: proxy.size
                                        )
                                    )
                                }
                                .onEnded { _ in
                                    dragStartPositions[item.id] = nil
                                }
                        )
                }
            }
            .navigationTitle("Mini Freeform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mini Freeform")
                            .font(.headline)
                        Text(model.items.isEmpty ? "Empty canvas" : "\(model.items.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CanvasControlBar(
                    canEditText: selectedTextItem != nil,
                    hasSelection: selectedItemID != nil,
                    hasItems: !model.items.isEmpty,
                    addRectangle: { addRectangle(in: proxy.size) },
                    addFreehand: { addFreehand(in: proxy.size) },
                    addText: { addText(in: proxy.size) },
                    editText: startEditingSelectedText,
                    deleteSelection: deleteSelectedItem,
                    clearCanvas: { isConfirmingClear = true }
                )
            }
            .alert("Edit Note", isPresented: $isEditingText) {
                TextField("Write something short", text: $textDraft, axis: .vertical)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    saveTextDraft()
                }
            } message: {
                Text("Update the selected text item.")
            }
            .confirmationDialog("Clear Canvas?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear Everything", role: .destructive) {
                    model.clear()
                    selectedItemID = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every item from the board.")
            }
        }
    }

    private var selectedTextItem: CanvasItem? {
        guard let selectedItemID else { return nil }
        return model.items.first(where: { $0.id == selectedItemID && $0.textValue != nil })
    }

    private func accessibilityIdentifier(for item: CanvasItem) -> String {
        switch item {
        case .rectangle:
            "rectangleItem"
        case .freehand:
            "freehandItem"
        case .text:
            "textItem"
        }
    }

    private func addRectangle(in size: CGSize) {
        let item = RectangleItem(
            position: model.suggestedPosition(in: size),
            size: CGSize(width: 160, height: 120),
            color: [.blue, .coral, .gold, .mint].randomElement() ?? .blue
        )
        model.add(.rectangle(item))
        selectedItemID = item.id
    }

    private func addFreehand(in size: CGSize) {
        let points = [
            CGPoint(x: 0, y: 4),
            CGPoint(x: 24, y: 22),
            CGPoint(x: 46, y: 14),
            CGPoint(x: 82, y: 42),
            CGPoint(x: 118, y: 12)
        ]
        let item = FreehandItem(
            position: model.suggestedPosition(in: size),
            points: points,
            strokeColor: [.coral, .blue, .mint].randomElement() ?? .coral,
            lineWidth: 4
        )
        model.add(.freehand(item))
        selectedItemID = item.id
    }

    private func addText(in size: CGSize) {
        let prompts = [
            "Weekly priorities",
            "Capture this idea",
            "Plan next action",
            "What matters today?"
        ]
        let item = TextItem(
            position: model.suggestedPosition(in: size),
            text: prompts.randomElement() ?? "Quick note",
            color: .primary
        )
        model.add(.text(item))
        selectedItemID = item.id
    }

    private func startEditingSelectedText() {
        guard let selectedTextItem, let currentText = selectedTextItem.textValue else { return }
        textDraft = currentText
        isEditingText = true
    }

    private func saveTextDraft() {
        guard let selectedItemID else { return }
        let trimmedText = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        model.updateText(of: selectedItemID, to: trimmedText)
    }

    private func deleteSelectedItem() {
        guard let selectedItemID else { return }
        model.remove(selectedItemID)
        self.selectedItemID = nil
    }

    private func clampedPosition(
        _ startPosition: CGPoint,
        translation: CGSize,
        item: CanvasItem,
        canvasSize: CGSize
    ) -> CGPoint {
        let proposedX = startPosition.x + translation.width
        let proposedY = startPosition.y + translation.height
        let metrics = item.metrics
        let horizontalInset = (metrics.width / 2) + 20
        let verticalInset = (metrics.height / 2) + 20

        return CGPoint(
            x: min(max(proposedX, horizontalInset), max(canvasSize.width - horizontalInset, horizontalInset)),
            y: min(max(proposedY, verticalInset + 20), max(canvasSize.height - verticalInset - 80, verticalInset + 20))
        )
    }
}

@main
struct MiniFreeformApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CanvasView()
            }
        }
    }
}
