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
    @State private var isShowingTemplate = false

    var sortedRecipes: [RecipeSetupData] {
        switch sortMode {
        case .newest: return recipes
        case .rating: return recipes.sorted { $0.rating > $1.rating }
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
                ContentUnavailableView("No recipes yet", systemImage: "book",
                                       description: Text("Create one with … → New Recipe."))
            }
            ForEach(sortedRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipeData: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .swipeActions(edge: .leading) {
                    Button("Use as template", systemImage: "doc.on.doc") {
                        templateRecipe = recipe.copyAsTemplate()
                        isShowingTemplate = true
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deleteRecipe)
        }
        .sheet(isPresented: $isShowingTemplate) {
            if let templateRecipe {
                RecipeContainerView(recipeSetupData: templateRecipe, isShowingNewRecipeView: $isShowingTemplate)
            }
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
                if recipe.isStarted {
                    Image(systemName: "timer").foregroundStyle(.green)
                }
                Spacer()
                StarRatingView(rating: .constant(recipe.rating), size: 12)
            }
            Text("\(Int(recipe.doughBallsCount))× \(Int(recipe.doughWeight)) g · \(Int(recipe.waterRatio)) % water · \(recipe.saltRatio, specifier: "%.1f") % salt")
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
    }
}

#Preview {
    NavigationStack { RecipesView() }
}
