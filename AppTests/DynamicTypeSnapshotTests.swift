import SwiftUI
import UIKit
import XCTest
@testable import Quicksilver
import Core
import ServicesAI

/// Snapshot tests at the largest Dynamic Type size (accessibility5), no third-party dependencies.
///
/// Renders Sanctum and Codex in a real `UIWindow` (so Form and other UIKit-backed views draw),
/// attaches the PNG to the result bundle (CI uploads AppTests.xcresult in the simulator proof
/// artifact), and checks that the render isn't blank. When a reference PNG exists in
/// `AppTests/__Snapshots__/`, the render must match it within `tolerance`. Without one, the test
/// records: it passes and attaches the image so the owner can review and commit it as a baseline.
@MainActor
final class DynamicTypeSnapshotTests: XCTestCase {
    private static let size = CGSize(width: 390, height: 844) // iPhone 16e points
    private static let tolerance = 0.02                       // fraction of differing pixels

    func testSanctumAtLargestDynamicType() throws {
        let view = SpatialSanctum(
            visualState: .idle, activeAspect: .quicksilver, livingStatus: "",
            onDestination: { _ in }, onInvoke: {}
        )
        // Sanctum's ambient/fluid TimelineViews derive phase from the wall clock, so pixels
        // are not reproducible run to run. Until a frozen-time render mode exists, Sanctum is
        // record-only: non-blank check + attachment, never compared against a baseline.
        try assertSnapshot(of: view, named: "sanctum-ax5", compareToBaseline: false)
    }

    func testCodexAtLargestDynamicType() throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        // Pin on-device availability: the real model's state depends on the runner's simulator
        // (Preparing / Not eligible / Available), which would change Codex row text and pixels.
        // The committed baseline shows "Preparing model".
        container.aiService.onDeviceProvider = OnDeviceAIProvider(model: PinnedOnDeviceModel())
        let view = NavigationStack { CodexView() }.environment(container)
        try assertSnapshot(of: view, named: "codex-ax5")
    }

    // MARK: - Harness

    private func assertSnapshot<V: View>(of view: V, named name: String, compareToBaseline: Bool = true) throws {
        let image = render(view)
        let png = try XCTUnwrap(image.pngData(), "render produced no PNG")

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertFalse(Self.isUniform(image), "\(name) rendered blank")

        let reference = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__/\(name).png")
        guard compareToBaseline else {
            print("SNAPSHOT recorded \(name) (record-only: render is time-dependent)")
            return
        }
        guard FileManager.default.fileExists(atPath: reference.path) else {
            print("SNAPSHOT recorded \(name) (no baseline yet; see the xcresult attachment)")
            return
        }
        // A baseline that exists but can't be read or decoded is a failure, not "no baseline".
        let data = try Data(contentsOf: reference)
        let baseline = try XCTUnwrap(UIImage(data: data), "\(name) baseline PNG could not be decoded")
        let diff = Self.differingFraction(image, baseline)
        XCTAssertLessThanOrEqual(diff, Self.tolerance, "\(name) differs from baseline by \(diff)")
    }

    private func render<V: View>(_ view: V) -> UIImage {
        let host = UIHostingController(
            rootView: view
                .environment(\.dynamicTypeSize, .accessibility5)
                .preferredColorScheme(.dark)
        )
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        // Attach to the host app's scene: a scene-less window never renders, so drawHierarchy
        // captured a blank image on CI.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.rootViewController = host
        let previousKey = scene?.windows.first { $0.isKeyWindow }
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0)) // let SwiftUI/Form settle
        CATransaction.flush()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: Self.size, format: format).image { context in
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) {
                // Fallback when the window isn't on screen: render the layer tree directly.
                window.layer.render(in: context.cgContext)
            }
        }
        window.isHidden = true
        previousKey?.makeKey() // keep focus/keyboard for later app-hosted tests
        return image
    }

    private static func rgba(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : nil
    }

    static func isUniform(_ image: UIImage) -> Bool {
        guard let pixels = rgba(image), pixels.count >= 4 else { return true }
        let first = Array(pixels[0..<4])
        return stride(from: 0, to: pixels.count, by: 4).allSatisfy { Array(pixels[$0..<$0 + 4]) == first }
    }

    static func differingFraction(_ lhs: UIImage, _ rhs: UIImage) -> Double {
        guard let left = rgba(lhs), let right = rgba(rhs), left.count == right.count else { return 1 }
        var differing = 0
        for index in stride(from: 0, to: left.count, by: 4) {
            let delta = (0..<3).map { abs(Int(left[index + $0]) - Int(right[index + $0])) }.max() ?? 0
            if delta > 16 { differing += 1 }
        }
        return Double(differing) / Double(left.count / 4)
    }
}

/// Deterministic on-device model for snapshots: always "Preparing model", never answers.
private struct PinnedOnDeviceModel: OnDeviceLanguageModel {
    var availability: OnDeviceModelAvailability { .modelNotReady }
    func respond(instructions: String?, prompt: String) async throws -> String {
        throw CancellationError()
    }
}
