# MiniFreeform

A lightweight SwiftUI canvas app inspired by Apple-style productivity experiences.

MiniFreeform lets users place simple shapes, draw freehand strokes, and add text notes on a clean canvas. It was built to showcase native Swift development, UI architecture, 2D drawing, and concurrency in a small but polished project.

## Preview

MiniFreeform includes:
- Draggable rectangles
- Freehand drawing elements
- Text notes


## Why I built this

I built MiniFreeform to strengthen my Swift and native Apple platform skills through a project that reflects the kind of interaction design used in productivity apps.

I wanted to create something small enough to finish, but meaningful enough to demonstrate:
- SwiftUI interface development
- object-oriented and protocol-oriented design
- CoreGraphics-style drawing concepts
- concurrency with `async/await`
- thoughtful UX through direct manipulation and autosave

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Architecture:** MVVM-style separation
- **Persistence:** `Codable` + local JSON storage
- **Concurrency:** `Task`, cancellation, async autosave

## Architecture

### Models
The canvas is built around three item types:
- `RectangleItem`
- `FreehandItem`
- `TextItem`

These are wrapped in a single `CanvasItem` enum so the app can manage heterogeneous canvas objects cleanly while preserving type safety.

### View Model
`CanvasViewModel` owns the canvas state and handles:
- adding items
- updating positions
- autosaving after changes
- loading saved canvas data on launch

Autosave is debounced using a cancellable `Task`, so repeated drag updates do not constantly write to disk.

### UI
`CanvasView` renders all items onto a blank canvas using SwiftUI.  
Each item is draggable, and toolbar actions allow quick insertion of rectangles, freehand elements, and text notes.

## Features

### 1. Interactive canvas
Users can place and move multiple note elements directly on the screen.

### 2. Freehand path rendering
Freehand strokes are rendered using `Path`, simulating lightweight drawing behavior.

### 3. Autosave
Canvas state is saved automatically as JSON after edits, without blocking the UI.

### 4. Clean native structure
The project is intentionally simple and readable, with a strong focus on maintainability and extension.

## What I learned

Through this project, I got more comfortable with:
- building native interfaces in SwiftUI
- modeling state for interactive UI
- using enums with associated values for flexible data models
- handling persistence with `Codable`
- using Swift concurrency for background work without freezing the interface

## Future Improvements

Planned next steps:
- editable text notes
- resizing and deleting canvas items
- color picker and styling controls
- real freehand gesture capture
- macOS optimization
- unit tests for persistence and item updates

## Running the project

1. Open the Xcode project
2. Select an iOS Simulator
3. Run with `Cmd + R`


## Author

**Arina Azmi**  
GitHub: [arinaazmi](https://github.com/arinaazmi)  
LinkedIn: [arina-azmi](https://linkedin.com/in/arina-azmi/)
