//
//  IconStudioView.swift
//  mgPizza_mk1
//
//  Icon-Studio: Selfie aufnehmen → Gesicht im Comic-Stil mit italienischem Schnurrbart (und Kochmütze) → 1024er Bild.
//  iOS erlaubt nicht, das App-Symbol zur Laufzeit durch ein selbst erzeugtes Bild zu ersetzen. Das fertige Bild wird
//  geteilt (z. B. an Claude oder AirDrop an den Mac) und in Xcode unter Assets › AppIcon eingesetzt.
//

import ImagePlayground
import PhotosUI
import SwiftUI
import UIKit

struct IconStudioView: View {
    /// Zeichnen mit Apple Intelligence (Image Playground) oder schneller Comic-Filter auf dem Foto
    enum Mode: Hashable { case drawing, filter }

    /// Zeichenstile von Image Playground
    enum DrawStyle: String, CaseIterable, Identifiable {
        case animation, illustration, sketch
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .animation: "Animation (3D comic)"
            case .illustration: "Illustration (drawn)"
            case .sketch: "Sketch"
            }
        }
        var playgroundStyle: ImagePlaygroundStyle {
            switch self {
            case .animation: .animation
            case .illustration: .illustration
            case .sketch: .sketch
            }
        }
    }

    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var mode: Mode = .drawing
    @State private var photo: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isWorking = false

    // Zeichnen (Image Playground)
    @State private var drawStyle: DrawStyle = .illustration
    @State private var wantsMustache = true
    @State private var wantsHat = true
    @State private var wantsPizza = true
    @State private var wantsFlag = true
    @State private var extraWish = ""
    @State private var isShowingPlayground = false
    @State private var drawing: UIImage?
    @State private var drawingURL: URL?

    // Filter
    @State private var result: IconRenderer.Output?
    @State private var options = IconRenderer.Options()
    @State private var filterURL: URL?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var preview: UIImage? { mode == .drawing ? drawing : result?.image }
    private var shareURL: URL? { mode == .drawing ? drawingURL : filterURL }

    /// Beschreibung für Image Playground (englisch, das versteht es am zuverlässigsten)
    private var concepts: [ImagePlaygroundConcept] {
        var list: [ImagePlaygroundConcept] = [.text("cheerful Italian pizza chef, head and shoulders portrait, app icon")]
        if wantsMustache { list.append(.text("big black curly Italian handlebar mustache")) }
        if wantsHat { list.append(.text("tall white chef's hat")) }
        if wantsPizza { list.append(.text("holding a pizza margherita")) }
        if wantsFlag { list.append(.text("background in the green, white and red colors of the Italian flag")) }
        let wish = extraWish.trimmingCharacters(in: .whitespacesAndNewlines)
        if !wish.isEmpty { list.append(.text(wish)) }
        return list
    }

    var body: some View {
        Form {
            Section {
                ZStack {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(.quaternary)
                    if let image = preview {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                            .accessibilityLabel("Preview of the app icon")
                    } else {
                        VStack(spacing: 8) {
                            Text("👨🏻‍🍳").font(.system(size: 64))
                            Text("Take a selfie or choose a photo").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if isWorking { ProgressView().controlSize(.large) }
                }
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)

                Picker("Method", selection: $mode) {
                    Text("Draw (Apple Intelligence)").tag(Mode.drawing)
                    Text("Photo filter").tag(Mode.filter)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section {
                if cameraAvailable {
                    Button("Take selfie", systemImage: "camera") { isShowingCamera = true }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from photos", systemImage: "photo.on.rectangle")
                }
            } footer: {
                Text("Best: face straight to the camera, good light, plain background.")
            }

            switch mode {
            case .drawing: drawingSections
            case .filter: filterSections
            }

            Section {
                if let shareURL, let image = preview {
                    ShareLink(item: shareURL, preview: SharePreview("Pizza app icon", image: Image(uiImage: image))) {
                        Label("Share icon (1024 × 1024)", systemImage: "square.and.arrow.up")
                    }
                }
            } footer: {
                Text("iOS doesn't let an app swap its own icon for a picture made on the phone. Send the picture to Claude in the chat (or AirDrop it to your Mac and drop it into Assets › AppIcon in Xcode). After the next build it's your home screen icon.")
            }
        }
        .navigationTitle("Icon studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !supportsImagePlayground { mode = .filter } }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in photo = image }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
            }
        }
        // Apple Intelligence: Foto als Vorlage, Beschreibung als „Konzepte“
        .imagePlaygroundSheet(isPresented: $isShowingPlayground, concepts: concepts,
                              sourceImage: photo.map { Image(uiImage: $0) }) { url in
            Task { await useDrawing(at: url) }
        }
        .imagePlaygroundGenerationStyle(drawStyle.playgroundStyle, in: DrawStyle.allCases.map(\.playgroundStyle))
        // Filter: neu rechnen, sobald Foto oder Einstellungen sich ändern
        .task(id: RenderKey(photo: photo, options: options, active: mode == .filter)) {
            guard mode == .filter, let photo else { return }
            try? await Task.sleep(for: .milliseconds(150))   // Regler: nicht bei jedem Zwischenschritt rechnen
            guard !Task.isCancelled else { return }
            isWorking = true
            let opts = options
            let output = await Task.detached(priority: .userInitiated) {
                IconRenderer.render(photo, options: opts)
            }.value
            guard !Task.isCancelled else { return }
            isWorking = false
            result = output
            filterURL = output.flatMap { Self.writePNG($0.image, name: "PizzaIcon-Filter.png") }
        }
    }

    // MARK: Zeichnen mit Apple Intelligence

    @ViewBuilder
    private var drawingSections: some View {
        if supportsImagePlayground {
            Section {
                Picker("Style", selection: $drawStyle) {
                    ForEach(DrawStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Italian mustache", systemImage: "mustache", isOn: $wantsMustache)
                Toggle("Chef's hat", systemImage: "frying.pan", isOn: $wantsHat)
                Toggle("Pizza in hand", systemImage: "circle.circle", isOn: $wantsPizza)
                Toggle("Italian flag background", systemImage: "flag", isOn: $wantsFlag)
                TextField("Extra wish (optional), e.g. “winking”", text: $extraWish)
                Button {
                    isShowingPlayground = true
                } label: {
                    Label(drawing == nil ? "Draw icon" : "Draw again", systemImage: "apple.intelligence")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } header: {
                Text("Drawing")
            } footer: {
                Text("Image Playground draws a real illustration from your photo (on the iPhone, nothing is uploaded). In the window you can pick a different look of the person, change the style or add ideas, then tap “Done”.")
            }
        } else {
            Section {
                Label("Drawing needs Apple Intelligence. Turn it on under Settings › Apple Intelligence & Siri, or use the photo filter.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
            }
        }
    }

    /// Ergebnis von Image Playground laden, quadratisch auf 1024 × 1024 bringen und als PNG ablegen
    private func useDrawing(at url: URL) async {
        isWorking = true
        defer { isWorking = false }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return }
        let square = Self.squareIcon(from: image)
        drawing = square
        drawingURL = Self.writePNG(square, name: "PizzaIcon.png")
    }

    /// Mittig quadratisch zuschneiden und auf 1024 skalieren
    private static func squareIcon(from image: UIImage) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }

    // MARK: Foto-Filter

    @ViewBuilder
    private var filterSections: some View {
        if photo != nil {
            if let result, !result.foundFace {
                Section {
                    Label("No face found. The mustache sits in the middle – move it with the sliders below.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section("Style") {
                Picker("Look", selection: $options.look) {
                    ForEach(IconRenderer.Look.allCases) { Text($0.title).tag($0) }
                }
                Picker("Background", selection: $options.background) {
                    ForEach(IconRenderer.Background.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Chef's hat", systemImage: "frying.pan", isOn: $options.chefHat)
                Toggle("Cut out person", systemImage: "person.crop.circle", isOn: $options.cutOut)
            }
            Section("Mustache") {
                Picker("Shape", selection: $options.mustache) {
                    ForEach(IconRenderer.Mustache.allCases) { Text($0.title).tag($0) }
                }
                Picker("Color", selection: $options.mustacheColor) {
                    ForEach(IconRenderer.HairColor.allCases) { Text($0.title).tag($0) }
                }
                LabeledSlider(title: "Size", value: $options.mustacheScale, range: 0.6...1.6)
                LabeledSlider(title: "Up / down", value: $options.mustacheOffsetY, range: -0.6...0.6)
                LabeledSlider(title: "Left / right", value: $options.mustacheOffsetX, range: -0.5...0.5)
                LabeledSlider(title: "Zoom", value: $options.zoom, range: 0.7...1.5)
            }
        }
    }

    private struct RenderKey: Equatable {
        var photo: UIImage?
        var options: IconRenderer.Options
        var active: Bool
        static func == (a: RenderKey, b: RenderKey) -> Bool {
            a.photo === b.photo && a.options == b.options && a.active == b.active
        }
    }

    private static func writePNG(_ image: UIImage, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard let data = image.pngData() else { return nil }
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return url
    }
}

/// Regler mit Beschriftung
private struct LabeledSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Slider(value: $value, in: range)
                .accessibilityLabel(Text(title))
        }
    }
}

/// Kamera (Frontkamera) für das Selfie
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
