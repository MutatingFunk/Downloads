//
//  DownloadController.swift
//  Downloads
//
//  Created by James Froggatt on 07.06.2017.
//  Copyright © 2017 James Froggatt. All rights reserved.
//

import UIKit
import MobileCoreServices

import Additions

class DownloadController: UIViewController {
	@IBOutlet private var collectionView: UICollectionView!
	@IBOutlet private var deleteButton: UIButton!
	
	private lazy var downloadManager: DownloadManager = DownloadManager.shared
	private lazy var fileManager: DownloadedFileManager = DownloadedFileManager.shared
	
	private var documentInteractionController: UIDocumentInteractionController?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if #available(iOS 11, *) {
			//fix for large title not shrinking on scroll
			self.navigationController?.navigationBar.prefersLargeTitles = true
		}
		fileManager.view = self
		downloadManager.view = self
		collectionView.dataSource = self
		collectionView.delegate = self
		if #available(iOS 11, *) {
			collectionView.dragDelegate = self
			collectionView.dropDelegate = self
			deleteButton.addInteraction(UIDropInteraction(delegate: self))
		}
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		collectionView.collectionViewLayout.invalidateLayout()
	}
	
	@IBAction private func addDownload() {
		performSegue(Segue.textEdit)
	}
	@IBAction private func openFirstDownload() {
		(collectionView.cellForItem(at: IndexPath(item: 0, section: Section.files.rawValue)) as? FileCell)?.share()
	}
	@IBAction private func openSecondDownload() {
		(collectionView.cellForItem(at: IndexPath(item: 1, section: Section.files.rawValue)) as? FileCell)?.share()
	}
	@IBAction private func openThirdDownload() {
		(collectionView.cellForItem(at: IndexPath(item: 2, section: Section.files.rawValue)) as? FileCell)?.share()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == Segue.textEdit.rawValue {
			let addDownloadController = segue.target as! AddDownloadController
			segue.targetPopover?.delegate = self
			addDownloadController.onReturn = {[weak self] urlString in
				self?.downloadManager.beginDownload(from: urlString)
			}
		}
	}
}

extension DownloadController: UIPopoverPresentationControllerDelegate {
	func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
		return .none
	}
}

private enum Section: Int {
	case invalid = -1
	case downloads = 0, files
	static let count = 2
	
	init(_ rawValue: Int) {
		self = Section(rawValue: rawValue) ?? .invalid
	}
	init(_ indexPath: IndexPath) {
		self.init(indexPath.section)
	}
}
private func indexPath(_ section: Section, _ item: Int) -> IndexPath {
	return IndexPath(item: item, section: section.rawValue)
}
private func indexSet(_ section: Section) -> IndexSet {
	return IndexSet(integer: section.rawValue)
}

private extension DownloadController {
	@IBAction func deletePressed() {
		UIAlertController(title: "Clear downloads", message: "Which downloads would you like to stop?", preferredStyle: .actionSheet)
			.addAction("All", style: .destructive) {[weak self] _ in
				guard let `self` = self else {return}
				self.collectionView.performBatchUpdates({
					self.downloadManager.cancelAll()
					self.fileManager.deleteAll()
				})
			}
			.addAction("Complete", style: .destructive) {[weak self] _ in
				self?.fileManager.deleteAll()
			}
			.addAction("Ongoing") {[weak self] _ in
				self?.downloadManager.cancelAll()
			}
			.addAction("Cancel", style: .cancel)
			.present(in: self, from: deleteButton, animated: true)
	}
}

extension DownloadController: DownloadProgressView {
	private func setProgress(_ progress: Double?, at index: Int) {
		if let cell = collectionView.cellForItem(at: indexPath(.downloads, index)) as? DownloadCell {
			cell.progress = progress.map(Float.init)
		}
	}
	
	func downloadBegan(at index: Int) {
		collectionView.insertItems(at: [indexPath(.downloads, index)])
	}
	func downloadPaused(at index: Int) {
		setProgress(nil, at: index)
	}
	func downloadResumed(at index: Int) {
		setProgress(0, at: index)
	}
	func download(at index: Int, gotProgress progress: Double) {
		setProgress(progress, at: index)
	}
	func downloadCancelled(at index: Int) {
		collectionView.deleteItems(at: [indexPath(.downloads, index)])
	}
	func downloadCompleted(at index: Int, toTempPath tempPath: URL, preferredFilename: String) {
		collectionView.deleteItems(at: [indexPath(.downloads, index)])
		fileManager.downloadCompleted(at: index, toTempPath: tempPath, preferredFilename: preferredFilename)
	}
	func downloadsCancelled() {
		collectionView.reloadSections(indexSet(.downloads))
	}
}
extension DownloadController: DownloadedFileView {
	func fileImported(at index: Int) {
		collectionView.insertItems(at: [indexPath(.files, index)])
	}
	func fileDeleted(at index: Int) {
		collectionView.deleteItems(at: [indexPath(.files, index)])
	}
	func filesDeleted() {
		collectionView.reloadSections(indexSet(.files))
	}
}

extension DownloadController: ShareDelegate {
	func shareFile(at url: URL, from view: UIView, keepingOriginal: Bool) {
		let doc = UIDocumentInteractionController(url: url)
		doc.delegate = self
		doc.presentOptionsMenu(from: view.frame, in: view.superview!, animated: true)
		self.documentInteractionController = doc
	}
}
extension DownloadController: UIDocumentInteractionControllerDelegate {
	func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
	 self.documentInteractionController = nil
	}
}

extension DownloadController: DownloadControlDelegate {
	func setPaused(_ newValue: Bool, forDownloadFrom url: URL) {
		if newValue {
			downloadManager.pauseDownload(from: url)
		} else {
			downloadManager.resumeDownload(from: url)
		}
	}
}

@available(iOS 11.0, *)
extension DownloadController: UICollectionViewDragDelegate {
	func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
		let params = UIDragPreviewParameters()
		params.backgroundColor = collectionView.backgroundColor
		if let rect = collectionView.cellForItem(at: indexPath)?.bounds {
			let section = Section(indexPath)
			params.visiblePath = UIBezierPath(roundedRect: rect, cornerRadius: section == .files ? 8 : 4)
		}
		return params
	}
	func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
		return dragItems(for: session, at: indexPath)
	}
	func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
		return dragItems(for: session, at: indexPath)
	}
	private func dragItems(for session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
		switch Section(indexPath) {
		case .downloads:
			let url = downloadManager.downloads[indexPath.item].key
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			dragItem.localObject = url
			return [dragItem]
		case .files:
			let url = fileManager.files[indexPath.item]
			guard let provider = NSItemProvider(contentsOf: url) else {return []}
			let dragItem = UIDragItem(itemProvider: provider)
			dragItem.localObject = url
			return [dragItem]
		case .invalid: return []
		}
	}
}

@available(iOS 11.0, *)
extension DownloadController: UICollectionViewDropDelegate {
	func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
		return session.canLoadObjects(ofClass: NSURL.self)
	}
	func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath target: IndexPath?) -> UICollectionViewDropProposal {
		return UICollectionViewDropProposal(operation: session.localDragSession == nil ? .copy : .cancel, intent: .unspecified)
	}
	func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
		guard coordinator.session.localDragSession == nil else {return}
		coordinator.session.loadObjects(ofClass: NSURL.self) {urls in
			for case let url as URL in urls {
				if url.isFileURL {
					self.fileManager.importFile(from: url, preferredFilename: nil, copyingSource: true)
				} else {
					self.downloadManager.beginDownload(from: url)
				}
			}
		}
	}
}
@available(iOS 11.0, *)
extension DownloadController: UIDropInteractionDelegate {//delete button
	func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
		return session.localDragSession != nil
	}
	func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
		return UIDropProposal(operation: .move)
	}
	func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
		guard let localSession = session.localDragSession else {return}
		for url in localSession.items.lazy.compactMap({$0.localObject as? URL}) {
			if url.isFileURL {
				fileManager.deleteFile(at: url)
			} else {
				downloadManager.cancelDownload(from: url)
			}
		}
	}
	
	func dropInteraction(_ interaction: UIDropInteraction, item: UIDragItem, willAnimateDropWith animator: UIDragAnimating) {
		animator.addAnimations {
			self.deleteButton.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
			self.deleteButton.tintColor = .red
		}
		animator.addCompletion {position in
			guard position == .end else {return}
			UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut], animations: {
				self.deleteButton.transform = .identity
				self.deleteButton.tintColor = nil
			})
		}
	}
}

extension DownloadController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return Section.count
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		switch Section(section) {
		case .invalid: return 0
		case .downloads: return downloadManager.downloads.keys.count
		case .files: return fileManager.files.count
		}
	}
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let flow = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		let flowInset = flow.map{$0.sectionInset} ?? UIEdgeInsets()
		var safeAreaInsets = UIEdgeInsets()
		if #available(iOS 11, *) {
			safeAreaInsets = collectionView.safeAreaInsets
		}
		let bounds = collectionView.bounds.insetBy(flowInset).insetBy(safeAreaInsets)
		let spacing = flow?.minimumInteritemSpacing ?? 0
		switch Section(indexPath) {
		case .invalid: return .zero
		case .downloads: return CGSize(width: collectionView.bounds.insetBy(safeAreaInsets).width, height: 50)
		case .files:
			let count = self.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
			let maxWidth = count == 1 ? bounds.width : (bounds.width - spacing) / 2
			return CGSize(width: min(maxWidth, 160), height: 160)
		}
	}
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		switch Section(indexPath) {
		case .invalid: preconditionFailure()
		case .downloads:
			let cell = collectionView.dequeueReusableCell(for: indexPath) as DownloadCell
			cell.downloadDelegate = self
			let (url, state) = downloadManager.downloads[indexPath.item]
			cell.download = (title: url.host ?? "", url: url)
			cell.progress = (state.task?.fractionCompleted).map(Float.init)
			return cell
		case .files:
			let cell = collectionView.dequeueReusableCell(for: indexPath) as FileCell
			cell.shareDelegate = self
			let url = fileManager.files[indexPath.item]
			cell.file = (title: url.lastPathComponent, url: url)
			return cell
		}
	}
}
