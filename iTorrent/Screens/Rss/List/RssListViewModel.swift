//
//  RssListViewModel.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 08.04.2024.
//

import Combine
import Foundation
import MvvmFoundation

class RssListViewModel: BaseViewModel {
    @Published var sections: [MvvmCollectionSectionModel] = []
    @Published var selectedIndexPaths: [IndexPath] = []

    required init() {
        super.init()
        setup()
    }

    var isRemoveAvailable: AnyPublisher<Bool, Never> {
        $selectedIndexPaths.map { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    func addFeed() {
        textInput(title: %"rsslist.add.title", placeholder: "https://", type: .URL, accept: %"common.add") { [unowned self] result in
            guard let result else { return }
            Task { try await rssProvider.addFeed(result) }
        }
    }

    func removeSelected() {
        let items = selectedIndexPaths.compactMap {
            (sections[$0.section].items[$0.item] as? RssFeedCellViewModel)?.model
        }

        alert(title: %"rsslist.remove.title", message: %"rsslist.remove.message", actions: [
            .init(title: %"common.cancel", style: .cancel),
            .init(title: %"common.delete", style: .destructive, action: { [rssProvider] in
                rssProvider.removeFeeds(items)
            })
        ])
    }

    @Injected private var rssProvider: RssFeedProvider
}

private extension RssListViewModel {
    func setup() {
        Task { await rssProvider.fetchUpdates() }
        disposeBag.bind {
            rssProvider.$rssModels.sink { [unowned self] models in
                var sections: [MvvmCollectionSectionModel] = []
                defer { self.sections = sections }

                sections.append(.init(id: "rss", items: models.map { model in
                    RssFeedCellViewModel.init(with: .init(rssModel: model, selectAction: { [unowned self] in
                        navigate(to: RssChannelViewModel.self, with: model, by: .show)
                    }))
                }))
            }
        }
    }
}
