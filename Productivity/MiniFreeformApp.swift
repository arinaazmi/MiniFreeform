//
//  MiniFreeformApp.swift
//
//  A lightweight SwiftUI canvas for simple note taking.
//

import Combine
import SwiftUI

enum CanvasColor: String, Codable {
    case blue
    case red
    case primary

    var swiftUIColor: Color {
        switch self {
        case .blue:
            return .blue
        case .red:
            return .red
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
            return item.id
        case .freehand(let item):
            return item.id
        case .text(let item):
            return item.id
        }
    }

    var position: CGPoint {
        get {
            switch self {
            case .rectangle(let item):
                return item.position
            case .freehand(let item):
                return item.position
            case .text(let item):
                return item.position
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

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("canvas.json")
        Task {
            await load()
        }
    }

    func add(_ item: CanvasItem) {
        items.append(item)
        scheduleSave()
    }

    func updatePosition(of id: UUID, to newPosition: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].position = newPosition
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [saveURL, items] in
            do {
                try await Task.sleep(for: .seconds(1))
                let data = try JSONEncoder().encode(items)
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
            items = try JSONDecoder().decode([CanvasItem].self, from: data)
        } catch {
            print("Failed to load canvas: \(error)")
        }
    }
}

struct CanvasItemView: View {
    let item: CanvasItem

    var body: some View {
        switch item {
        case .rectangle(let rectangle):
            Rectangle()
                .fill(rectangle.color.swiftUIColor)
                .frame(width: rectangle.size.width, height: rectangle.size.height)
        case .freehand(let freehand):
            Path { path in
                guard let firstPoint = freehand.points.first else { return }
                path.move(to: .zero)
                for point in freehand.points.dropFirst() {
                    path.addLine(to: CGPoint(
                        x: point.x - firstPoint.x,
                        y: point.y - firstPoint.y
                    ))
                }
            }
            .stroke(freehand.strokeColor.swiftUIColor, lineWidth: freehand.lineWidth)
            .frame(width: 140, height: 80, alignment: .topLeading)
        case .text(let text):
            Text(text.text)
                .foregroundStyle(text.color.swiftUIColor)
                .padding(6)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct CanvasView: View {
    @StateObject private var model = CanvasViewModel()
    @State private var dragStartPositions: [UUID: CGPoint] = [:]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
                .ignoresSafeArea()

            ForEach(model.items) { item in
                CanvasItemView(item: item)
                    .position(item.position)
                    .accessibilityIdentifier(accessibilityIdentifier(for: item))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let startPosition = dragStartPositions[item.id] ?? item.position
                                dragStartPositions[item.id] = startPosition
                                model.updatePosition(
                                    of: item.id,
                                    to: CGPoint(
                                        x: startPosition.x + value.translation.width,
                                        y: startPosition.y + value.translation.height
                                    )
                                )
                            }
                            .onEnded { _ in
                                dragStartPositions[item.id] = nil
                            }
                    )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: addRectangle) {
                    Label("Rectangle", systemImage: "square.on.square")
                }
                .accessibilityIdentifier("addRectangleButton")
                Button(action: addFreehand) {
                    Label("Freehand", systemImage: "pencil.tip")
                }
                .accessibilityIdentifier("addFreehandButton")
                Button(action: addText) {
                    Label("Text", systemImage: "text.cursor")
                }
                .accessibilityIdentifier("addTextButton")
            }
        }
    }

    private func accessibilityIdentifier(for item: CanvasItem) -> String {
        switch item {
        case .rectangle:
            return "rectangleItem"
        case .freehand:
            return "freehandItem"
        case .text:
            return "textItem"
        }
    }

    private func addRectangle() {
        let item = RectangleItem(
            position: CGPoint(x: 100, y: 120),
            size: CGSize(width: 100, height: 70),
            color: .blue
        )
        model.add(.rectangle(item))
    }

    private func addFreehand() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 25),
            CGPoint(x: 70, y: 10),
            CGPoint(x: 110, y: 45)
        ]
        let item = FreehandItem(
            position: CGPoint(x: 150, y: 220),
            points: points,
            strokeColor: .red,
            lineWidth: 3
        )
        model.add(.freehand(item))
    }

    private func addText() {
        let item = TextItem(
            position: CGPoint(x: 180, y: 140),
            text: "Hello",
            color: .primary
        )
        model.add(.text(item))
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
