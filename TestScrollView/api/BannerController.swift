//
//  BannerController.swift
//  TestScrollView
//
//  Created by Shane Whitehead on 30/11/18.
//  Copyright © 2018 Beam Communications. All rights reserved.
//

import Foundation
import UIKit

public protocol RefreshController {
	var view: UIView { get }
	var desiredHeight: CGFloat { get }
	
	func beginRefreshing()
	func endRefreshing()
}

public class BannerController: NSObject {
	
	enum BannerState {
		case open
		case closed
		
		// Call me lazy ;)
		var isOpen: Bool {
			return self == .open
		}
	}
	
	enum KeyPath: String {
		case contentOffset = "contentOffset"
		case contentSize = "contentSize"
	}
	
	fileprivate static var context = "BannerController.observerContext"
	
	var refreshState: BannerState = .closed
	
	open var refreshController: RefreshController? {
		didSet {
			uninstallRefresherIfNeeded(oldValue)
			installRefresherIfNeeded()
		}
	}
	
	// I was hoping to avoid this...
	weak var scrollView: UIScrollView?
	
	public func install(on scrollView: UIScrollView) {
		self.scrollView = scrollView
		scrollView.addObserver(self, forKeyPath: KeyPath.contentOffset.rawValue, options: [.initial, .new], context: &BannerController.context)
		scrollView.addObserver(self, forKeyPath: KeyPath.contentSize.rawValue, options: [.initial, .new], context: &BannerController.context)
		
		uninstallRefresherIfNeeded(refreshController)
		installRefresherIfNeeded()
	}
	
	func uninstallRefresherIfNeeded(_ controller: RefreshController?) {
		guard let controller = controller else {
			return
		}
		controller.view.removeFromSuperview()
	}
	
	func installRefresherIfNeeded() {
		guard let controller = refreshController, let scrollView = scrollView else {
			return
		}
		controller.view.frame = CGRect.zero
		scrollView.addSubview(controller.view)
	}
	
	override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		guard context == &BannerController.context else {
			return
		}
		guard let stringPath = keyPath, let path = KeyPath(rawValue: stringPath) else {
			return
		}
		guard let scrollView = object as? UIScrollView else {
			return
		}
		guard scrollView.isUserInteractionEnabled && !scrollView.isHidden else {
			return
		}

		if let refreshController = refreshController {
			update(refreshController, in: scrollView)
		}
		wasDragged = scrollView.isDragging
	}

	// Determines if the "scroll view" was previously been dragged
	var wasDragged: Bool = false

	func update(_ refreshController: RefreshController, in scrollView: UIScrollView) {
		let refreshView = refreshController.view
		let desiredHeight = refreshController.desiredHeight
		
		// This will give me the height to be used for the header view :)
		let actualOffset = (scrollView.contentOffset.y * -1) - scrollView.safeAreaInsets.top
		// Calculate a y position which will place the view at the "top" of the scroll view
		// Probably also need to include the contentInsets
		let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y

		if refreshState.isOpen {
			// The intent is to resize the view if the scrollview is pulled down, but prevent
			// it from been collapsed, making it "sticky"
			let height = max(actualOffset, desiredHeight)
			refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: height)

			let progress = height / desiredHeight
			
		} else if actualOffset > 0 && !refreshState.isOpen {
			// The scrollview is been pulled down, beyond it's "0" point
			//let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y
			// Calculate the desired height based on the expanded state.
			// If the view is already expanded, then we want to allow it to "grow" beyond its
			// desired height, but not shrink.
			// If it's not expanded, then we can allow it to shrink...
			let height = refreshState.isOpen ? (actualOffset < desiredHeight ? desiredHeight : actualOffset) : actualOffset
			refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: height)
			
			let progress = height / desiredHeight
			
			// Was the view previously been dragged, and was it dragged beyon our "desired" height?
			// We don't want to "retrigger" a beginRefresh if the resfresh is already "open"
			if !refreshState.isOpen && wasDragged && !scrollView.isDragging && actualOffset >= desiredHeight {
				// This can be used to animate the view open as well :)
				beginRefreshing()
			}
		}
	}
	
	func beginRefreshing() {
		guard let scrollView = scrollView, let controller = refreshController, !refreshState.isOpen else {
			return
		}
		let refreshView = controller.view
		let desiredHeight = controller.desiredHeight

		let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y

		// I had been setting this in the completion block of the animation, but
		// it was causing this function to be recalled
		self.refreshState = .open
		scrollView.bringSubviewToFront(refreshView)
		let frame = refreshView.frame
		refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: frame.height)
		UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
			scrollView.contentInset.top += desiredHeight
		}) { (_) in
			controller.beginRefreshing()
		}
	}
	
	func endRefreshing() {
		guard let scrollView = scrollView, let controller = refreshController, refreshState.isOpen else {
			return
		}
		let refreshView = controller.view
		let desiredHeight = controller.desiredHeight

		// Set the content inset to accomidate the view
		// Need to take into consideration the existing inset
		scrollView.bringSubviewToFront(refreshView)
		let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y + scrollView.contentInset.top
		UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
			scrollView.contentInset.top -= desiredHeight
			refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: 0)
		}) { (_) in
			self.refreshState = .closed
			controller.endRefreshing()
		}
	}
}
