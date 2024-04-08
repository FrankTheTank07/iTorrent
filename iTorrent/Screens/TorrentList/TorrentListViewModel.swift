//
//  TorrentListViewModel.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 29/10/2023.
//

import Combine
import LibTorrent
import MvvmFoundation
import SwiftData

extension TorrentListViewModel {
    enum Sort: CaseIterable, Codable {
        case alphabetically
        case creationDate
        case addedDate
        case size
    }
}

class TorrentListViewModel: BaseViewModel {
    @Published var sections: [MvvmCollectionSectionModel] = []
    @Published var searchQuery: String = ""
    @Published var title: String = ""

    var isGroupedByState: CurrentValueRelay<Bool> {
        PreferencesStorage.shared.$torrentListGroupedByState
    }

    var sortingType: CurrentValueRelay<Sort> {
        PreferencesStorage.shared.$torrentListSortType
    }

    var sortingReverced: CurrentValueRelay<Bool> {
        PreferencesStorage.shared.$torrentListSortReverced
    }

    required init() {
        super.init()
        title = "iTorrent"

        Task {
            try await Task.sleep(for: .seconds(0.1))

            let groupsSortingArray = PreferencesStorage.shared.$torrentListGroupsSortingArray
            let torrentSectionChanged = TorrentService.shared.updateNotifier.filter { $0.oldSnapshot.friendlyState != $0.handle.snapshot.friendlyState }.map{_ in ()}.prepend([()])

            Publishers.combineLatest(
                torrentSectionChanged,
                TorrentService.shared.$torrents,
                $searchQuery,
                sortingType,
                sortingReverced,
                isGroupedByState,
                groupsSortingArray
            ) { _, torrentHandles, searchQuery, sortingType, sortingReverced, isGrouping, sortingArray in
                var torrentHandles = torrentHandles
                if !searchQuery.isEmpty {
                    torrentHandles = torrentHandles.filter { Self.searchFilter($0.snapshot.name, by: searchQuery) }
                }
                return (torrentHandles.sorted(by: sortingType, reverced: sortingReverced), isGrouping, sortingArray)
            }
            .map { [unowned self] torrents, isGrouping, sortingArray in
                if isGrouping {
                    return makeGroupedSections(with: torrents, by: sortingArray)
                } else {
                    return makeUngroupedSection(with: torrents)
                }
            }
            .assign(to: &$sections)
        }
    }

    static func searchFilter(_ text: String, by query: String) -> Bool {
        query.split(separator: " ").allSatisfy { text.localizedCaseInsensitiveContains($0) }
    }
}

extension TorrentListViewModel {
    func preferencesAction() {
        navigate(to: PreferencesViewModel.self, by: .show)
    }

    func showRss() {
        navigate(to: RssListViewModel.self, by: .show)
    }

    func addTorrent(by url: URL) {
        guard let navigationService = navigationService?() else { return }
        TorrentAddViewModel.present(with: url, from: navigationService)
    }

    func resumeAllSelected(at indexPaths: [IndexPath]) {
        let torrentModels = indexPaths.compactMap { sections[$0.section].items[$0.item] as? TorrentListItemViewModel }
        torrentModels.forEach { $0.torrentHandle.resume() }
    }

    func pauseAllSelected(at indexPaths: [IndexPath]) {
        let torrentModels = indexPaths.compactMap { sections[$0.section].items[$0.item] as? TorrentListItemViewModel }
        torrentModels.forEach { $0.torrentHandle.pause() }
    }

    func rehashAllSelected(at indexPaths: [IndexPath]) {
        let torrentModels = indexPaths.compactMap { sections[$0.section].items[$0.item] as? TorrentListItemViewModel }

        alert(title: %"details.rehash.title", message: %"details.rehash.message", actions: [
            .init(title: %"common.cancel", style: .cancel),
            .init(title: %"details.rehash.action", style: .destructive, action: {
                torrentModels.forEach { $0.torrentHandle.rehash() }
            })
        ])
    }

    func deleteAllSelected(at indexPaths: [IndexPath]) {
        let torrentModels = indexPaths.compactMap { sections[$0.section].items[$0.item] as? TorrentListItemViewModel }
        let message = torrentModels.map { $0.torrentHandle.snapshot.name }.joined(separator: "\n\n")

        alert(title: %"torrent.remove.title", message: message, actions: [
            .init(title: %"torrent.remove.action.dropData", style: .destructive, action: {
                torrentModels.forEach { torrentModel in
                    TorrentService.shared.removeTorrent(by: torrentModel.torrentHandle.infoHashes, deleteFiles: true)
                }
            }),
            .init(title: %"torrent.remove.action.keepData", style: .default, action: {
                torrentModels.forEach { torrentModel in
                    TorrentService.shared.removeTorrent(by: torrentModel.torrentHandle.infoHashes, deleteFiles: false)
                }
            }),
            .init(title: %"common.cancel", style: .cancel)
        ])
    }

    func removeTorrent(_ torrentHandle: TorrentHandle) {
        alert(title: %"torrent.remove.title", message: torrentHandle.name, actions: [
            .init(title: %"torrent.remove.action.dropData", style: .destructive, action: {
                TorrentService.shared.removeTorrent(by: torrentHandle.infoHashes, deleteFiles: true)
            }),
            .init(title: %"torrent.remove.action.keepData", style: .default, action: {
                TorrentService.shared.removeTorrent(by: torrentHandle.infoHashes, deleteFiles: false)
            }),
            .init(title: %"common.cancel", style: .cancel)
        ])
    }
}

private extension TorrentListViewModel {
    func makeUngroupedSection(with torrents: [TorrentHandle]) -> [MvvmCollectionSectionModel] {
        [.init(id: "torrents", style: .platformPlain, showsSeparators: true, items: torrents.map {
            let vm = TorrentListItemViewModel(with: $0)
            vm.navigationService = { [weak self] in self?.navigationService?() }
            return vm
        })]
    }

    static func getStateGroupintIndex(_ state: TorrentHandle.State, from sortingArray: [TorrentHandle.State]) -> Int {
        let index = sortingArray.firstIndex(of: state)
        assert(index != nil, "SortingArray missed \(state) state. SortingArray should contain all possible states of \(TorrentHandle.State.self)")
        return index ?? -1
    }

    func makeGroupedSections(with torrents: [TorrentHandle], by sortingArray: [TorrentHandle.State]) -> [MvvmCollectionSectionModel] {
        let dictionary = [TorrentHandle.State: [TorrentHandle]](grouping: torrents, by: \.snapshot.friendlyState)
        return dictionary.sorted { Self.getStateGroupintIndex($0.key, from: sortingArray) < Self.getStateGroupintIndex($1.key, from: sortingArray) }.map { section in
            MvvmCollectionSectionModel(id: section.key.name, header: section.key.name, style: .platformPlain, items: section.value.map {
                let vm = TorrentListItemViewModel(with: $0)
                vm.navigationService = { [weak self] in self?.navigationService?() }
                return vm
            })
        }
    }
}

private extension Array where Element == TorrentHandle {
    func sorted(by type: TorrentListViewModel.Sort, reverced: Bool) -> [Element] {
        let res = filter(\.isValid).sorted { first, second in
            switch type {
            case .alphabetically:
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .creationDate:
                return first.creationDate ?? Date() > second.creationDate ?? Date()
            case .addedDate:
                return first.metadata.dateAdded > second.metadata.dateAdded
            case .size:
                return first.totalWanted > second.totalWanted
            }
        }

        return reverced ? res.reversed() : res
    }
}
