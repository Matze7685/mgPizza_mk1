//
//  IconStudioView.swift
//  mgPizza_mk1
//
//  Icon-Studio: Selfie aufnehmen → Gesicht im Comic-Stil mit italienischem Schnurrbart (und Kochmütze) → 1024er Bild.
//  iOS erlaubt nicht, das App-Symbol zur Laufzeit durch ein selbst erzeugtes Bild zu ersetzen. Das fertige Bild wird
//  geteilt (z. B. an Claude oder AirDrop an den Mac) und in Xcode unter Assets › AppIcon eingesetzt.
//

import PhotosUI
import SwiftUI
import UIKit

struct IconStudioView: View {
    @State private var photo: UIImage?
    @State private var result: IconRenderer.Output?
    @State private var options = IconRenderer.Options()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isWorking = false
    @State private var fileURL: URL?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        Form {
            Section {
                ZStack {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(.quaternary)
                    if let image = result?.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
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

                if let result, !result.foundFace {
                    Label("No face found. The mustache sits in the middle – move it with the sliders below.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
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

            if photo != nil {
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
                Section {
                    if let fileURL, let image = result?.image {
                        ShareLink(item: fileURL, preview: SharePreview("Pizza app icon", image: Image(uiImage: image))) {
                            Label("Share icon (1024 × 1024)", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("iOS doesn't let an app swap its own icon for a picture made on the phone. Send the picture to Claude in the chat (or AirDrop it to your Mac and drop it into Assets › AppIcon in Xcode). After the next build it's your home screen icon.")
                }
            }
        }
        .navigationTitle("Icon studio")
        .navigationBarTitleDisplayMode(.inline)
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
        // Neu rechnen, sobald Foto oder Einstellungen sich ändern
        .task(id: RenderKey(photo: photo, options: options)) {
            guard let photo else { return }
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
            fileURL = output.flatMap { Self.writePNG($0.image) }
        }
    }

    private struct RenderKey: Equatable {
        var photo: UIImage?
        var options: IconRenderer.Options
        static func == (a: RenderKey, b: RenderKey) -> Bool { a.photo === b.photo && a.options == b.options }
    }

    private static func writePNG(_ image: UIImage) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PizzaIcon.png")
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
