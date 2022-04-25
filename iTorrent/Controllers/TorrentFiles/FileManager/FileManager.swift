//
//  FileManager.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 22.04.2022.
//

import Foundation
import ReactiveKit
import MVVMFoundation
import TorrentKit

class FileManager {
    let rawFiles: [FileEntity]
    let root: DirectoryEntity

    private let bag = DisposeBag()

    deinit {
        print("FileManager deinit")
    }

    init(with torrent: TorrentHandle) {
        let root = DirectoryEntity(name: "")
        var rawFiles = [FileEntity]()

        let files = torrent.files
        for fileNum in files.enumerated() {
            let file = fileNum.element
            let parts = file.path.split(separator: "/")
            var currentDirectory = root
            for part in parts {
                let part = String(part)

                if part == file.name {
                    let fileEntity = FileEntity(file: file, id: fileNum.offset)
                    currentDirectory.files[part] = fileEntity
                    rawFiles.append(fileEntity)
                    break
                }

                // Create and move to next folder
                var nextDir: DirectoryEntity? = currentDirectory.files[part] as? DirectoryEntity
                if nextDir == nil {
                    nextDir = DirectoryEntity(name: part)
                    currentDirectory.files[part] = nextDir
                }
                currentDirectory = nextDir!
            }
        }

        self.rawFiles = rawFiles.sorted(by: { $0.id < $1.id })

        if root.files.values.count == 1,
           let first = root.files.values.first as? DirectoryEntity,
           first.name == torrent.name
        {
            self.root = first
        } else {
            self.root = root
        }

        // Binding
        torrent.rx.progress.observeNext { _ in
            for file in torrent.files.enumerated() {
                DispatchQueue.main.async {
                    rawFiles[file.offset].update(with: file.element)
                }
            }
        }.dispose(in: bag)
    }
}
