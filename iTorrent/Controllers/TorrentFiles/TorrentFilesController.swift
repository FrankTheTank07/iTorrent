//
//  TorrentFilesController.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 21.04.2022.
//

import MVVMFoundation
import QuickLook
import UIKit

class TorrentFilesController: MvvmTableViewController<TorrentFilesViewModel> {
    var previewDataSource = TorrentFilesControllerPreviewDataSource()
    var dataSource: DiffableDataSource<FileEntityProtocol>?

    override func setupView() {
        super.setupView()

        dataSource = DiffableDataSource<FileEntityProtocol>(tableView: tableView, cellProvider: { [unowned self] tableView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let file as FileEntity:
                let cell = tableView.dequeue(for: indexPath) as TorrentFileCell
                cell.setup(with: file)
                cell.bind(in: cell.reuseBag) {
                    cell.valueChanged.observeNext { priority in viewModel.setTorrentFilePriority(priority, at: file.id) }
                }
                return cell
            case let directory as DirectoryEntity:
                let cell = tableView.dequeue(for: indexPath) as TorrentDirectoryCell
                cell.setup(with: directory)
                return cell
            default: return UITableViewCell()
            }
        })

        tableView.register(cell: TorrentFileCell.self)
        tableView.register(cell: TorrentDirectoryCell.self)
    }

    override func binding() {
        super.binding()
        bind(in: bag) {
            viewModel.$sections.observeNext { [unowned self] sections in
                var snapshot = DiffableDataSource<FileEntityProtocol>.Snapshot()
                snapshot.append(sections)
                dataSource?.apply(snapshot)
            }

            tableView.reactive.selectedRowIndexPath.observeNext { [unowned self] indexPath in
                if let cell = tableView.cellForRow(at: indexPath) as? TorrentFileCell,
                   let file = viewModel.getFile(at: indexPath.row)
                {
                    if file.progress == 1 {
                        previewDataSource.previewURL = URL(fileURLWithPath: file.getFullPath(), isDirectory: false)
                        let qlvc = QLPreviewController()
                        qlvc.dataSource = previewDataSource
                        present(qlvc, animated: true)
                    } else { cell.triggerSwitch() }
                    return
                }
                viewModel.selectItem(at: indexPath)
            }
        }
    }
}

class TorrentFilesControllerPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    var previewURL: URL?

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let url = previewURL else { fatalError() }
        return url as NSURL
    }
}