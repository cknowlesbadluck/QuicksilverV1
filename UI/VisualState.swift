import Foundation
import Core

// VisualState now lives in Core so Brain / Nexus / Aspect policy can own it.
// This file remains only as a stable import path for existing UI code.
// Prefer `import Core` and use VisualState directly in new code.

// Re-export for source compatibility during the migration window.
public typealias VisualState = Core.VisualState
