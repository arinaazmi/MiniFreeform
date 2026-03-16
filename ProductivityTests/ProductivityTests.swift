//
//  ProductivityTests.swift
//  ProductivityTests
//
//  Created by Arina on 2026-03-16.
//

import CoreGraphics
import Foundation
import Testing
@testable import Productivity

struct ProductivityTests {

    @Test
    @MainActor
    func canvasModelCanAddEditAndRemoveItems() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let model = CanvasViewModel(saveURL: url, autoload: false)

        let text = TextItem(position: CGPoint(x: 120, y: 140), text: "Draft", color: .primary)
        model.add(.text(text))
        #expect(model.items.count == 1)

        model.updateText(of: text.id, to: "Final note")
        #expect(model.items.first?.textValue == "Final note")

        model.updatePosition(of: text.id, to: CGPoint(x: 180, y: 220))
        #expect(model.items.first?.position == CGPoint(x: 180, y: 220))

        model.remove(text.id)
        #expect(model.items.isEmpty)
    }

    @Test
    @MainActor
    func suggestedPositionStaysWithinSmallCanvas() async throws {
        let model = CanvasViewModel(
            saveURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            autoload: false
        )

        let point = model.suggestedPosition(in: CGSize(width: 220, height: 260))
        #expect(point.x >= 90)
        #expect(point.x <= 130)
        #expect(point.y >= 120)
        #expect(point.y <= 150)
    }
}
