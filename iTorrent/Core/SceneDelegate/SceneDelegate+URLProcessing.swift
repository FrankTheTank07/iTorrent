//
//  SceneDelegate+URLProcessing.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 06.04.2024.
//

import LibTorrent
import UIKit

extension SceneDelegate {
    func processURL(_ url: URL) {
        if tryOpenTorrentDetails(with: url) { return }
        if tryOpenAddTorrent(with: url) { return }
        if tryOpenRemoteAddTorrent(with: url) { return }
    }
}

private extension SceneDelegate {
    // Open torrent details by hash from Life Activity
    func tryOpenTorrentDetails(with url: URL) -> Bool {
        let prefix = "iTorrent:hash:"

        guard url.absoluteString.hasPrefix(prefix) else { return false }
        let hash = url.absoluteString.replacingOccurrences(of: prefix, with: "")

        guard let torrent = TorrentService.shared.torrents.first(where: { $0.infoHashes.best.hex == hash })
        else { return false }

        AppDelegate.showTorrentDetailScreen(with: torrent)
        return true
    }

    // Add new torrent flow by file URL
    func tryOpenAddTorrent(with url: URL) -> Bool {
        guard url.absoluteString.hasPrefix("file:///"),
              let rootViewController = window?.rootViewController?.topPresented
        else {
            return false
        }

        TorrentAddViewModel.present(with: url, from: rootViewController)
        return true
    }

    // Add new torrent flow by file remote URL
    func tryOpenRemoteAddTorrent(with url: URL) -> Bool {
        guard url.absoluteString.hasPrefix("http"),
              let rootViewController = window?.rootViewController?.topPresented
        else { return false }

        TorrentAddViewModel.presentRemote(with: url, from: rootViewController)
        return true
    }
}
