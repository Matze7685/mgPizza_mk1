//
//  RecipesView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Liste aller gespeicherten Teigrezepte (zum Ausprobieren & Vergleichen).
struct RecipesView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case rating = "Rating"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeSetupData.createdAt, order: .reverse) private var recipes: [RecipeSetupData]
    @State private var sortMode: SortMode = .newest
    @State private var templateRecipe: RecipeSetupData?

    private var isShowingTemplate: Binding<Bool> {
        Binding { templateRecipe != nil } set: { if !$0 { templateRecipe = nil } }
    }

    var sortedRecipes: [RecipeSetupData] {
        switch sortMode {
        case .newest: return recipes.filter(\.isActive) + recipes.filter { !$0.isActive }   // laufende zuerst
        case .rating: return recipes.sorted { ($0.isActive ? 1 : 0, $0.rating) > ($1.isActive ? 1 : 0, $1.rating) }
        }
    }

    var body: some View {
        List {
            Picker("Sort", selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if recipes.isEmpty {
                ContentUnavailableView {
                    Label("No recipes yet", systemImage: "book")
                } description: {
                    Text("Create one with the + button.")
                } actions: {
                    Button("New dough") { AppRouter.shared.showNewRecipe = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            ForEach(sortedRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeData: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .listRowBackground(recipe.isActive ? Theme.doughBackground : nil)
                .swipeActions(edge: .leading) {
                    Button("Use as template", systemImage: "doc.on.doc") {
                        templateRecipe = recipe.copyAsTemplate()
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deleteRecipe)
        }
        // sheet(item:) statt isPresented: sonst ist das Rezept beim ersten Öffnen noch nil (leeres Sheet)
        .sheet(item: $templateRecipe) { recipe in
            RecipeContainerView(recipeSetupData: recipe, isShowingNewRecipeView: isShowingTemplate)
        }
    }

    func deleteRecipe(at offsets: IndexSet) {
        let list = sortedRecipes
        withAnimation {
            offsets.forEach { index in
                list[index].stopTimers()
                modelContext.delete(list[index])
            }
        }
    }
}

struct RecipeRow: View {
    var recipe: RecipeSetupData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.displayName).font(.headline)
                if recipe.isActive {
                    Text("Running")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.white)
                }
                Spacer()
                StarRatingView(rating: .constant(recipe.rating), size: 12)
            }
            Text("\(recipe.isDetroit ? "Detroit " : "")\(Int(recipe.doughBallsCount))× \(Int(recipe.doughWeight)) g · \(Int(recipe.waterRatio)) % water · \(recipe.saltRatio, specifier: "%.1f") % salt")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(recipe.coolTime)) h fridge @ \(Int(recipe.coolTemp)) °C · \(Int(recipe.roomTime)) h room @ \(Int(recipe.roomTemp)) °C")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Int
    var size: CGFloat = 24
    var isEditable = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? .yellow : .gray)
                    .onTapGesture {
                        if isEditable { rating = (rating == star ? 0 : star) }
                    }
            }
        }
        // VoiceOver: ein Element „Bewertung, 3 von 5 Sternen“, mit Wischen nach oben/unten änderbar
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(Text("\(rating) of 5 stars"))
        .accessibilityAdjustableAction { direction in
            guard isEditable else { return }
            switch direction {
            case .increment: rating = min(rating + 1, 5)
            case .decrement: rating = max(rating - 1, 0)
            @unknown default: break
            }
        }
    }
}

#Preview {
    NavigationStack { RecipesView() }
}
