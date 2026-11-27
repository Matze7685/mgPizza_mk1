//
//  MenuPDF.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Speisekarte als hübsches PDF zum Verschicken
enum MenuPDF {
    @MainActor
    static func render(title: String, date: Date, pizzas: [MenuPizza]) -> URL? {
        let card = MenuCardView(title: title, date: date,
                                items: pizzas.map { ($0.name, $0.info, $0.toppingsText) })
            .frame(width: 595)          // A4-Breite in Punkt
        let renderer = ImageRenderer(content: card)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(String(localized: "Menu")).pdf")
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: 595, height: max(size.height, 842)))
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            // oben ausrichten
            context.translateBy(x: 0, y: box.height - size.height)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

struct MenuCardView: View {
    var title: String
    var date: Date
    var items: [(name: String, info: String, toppings: String)]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("🍕").font(.system(size: 48))
                Text(title).font(.system(size: 34, weight: .bold, design: .serif))
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.system(size: 16, design: .serif)).foregroundStyle(.secondary)
            }
            Rectangle().fill(Color.red.opacity(0.6)).frame(width: 120, height: 2)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).font(.system(size: 20, weight: .semibold, design: .serif))
                            if !item.info.isEmpty {
                                Text(item.info).font(.system(size: 13, design: .serif)).italic().foregroundStyle(.secondary)
                            }
                            if !item.toppings.isEmpty {
                                Text(item.toppings).font(.system(size: 14, design: .serif))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Please reply with number × count, e.g. “1×2, 3×1”. Thanks!")
                .font(.system(size: 13, design: .serif)).italic().foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .background(Theme.paper)
        .environment(\.colorScheme, .light)
    }
}

extension Notification.Name {
    /// Wechselt in den Tab „Einkauf“
    static let showShoppingList = Notification.Name("showShoppingList")
}
