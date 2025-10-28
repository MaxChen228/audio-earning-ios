//
//  BookListViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

@MainActor
final class BookListViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: APIService
    private var hasLoaded = false

    init(service: APIService = .shared) {
        self.service = service
    }

    func loadBooks(force: Bool = false) {
        guard !hasLoaded || force else { return }
        hasLoaded = true

        Task { [weak self] in
            await self?.fetchBooks()
        }
    }

    private func fetchBooks() async {
        isLoading = true
        errorMessage = nil

        do {
            let responses = try await service.fetchBooks()
            books = responses.map { Book(id: $0.id, title: $0.title) }
        } catch {
            errorMessage = error.localizedDescription
            books = []
        }

        isLoading = false
    }
}
