//
//  MainTableViewController.swift
//  TestScrollView
//
//  Created by Shane Whitehead on 29/11/18.
//  Copyright © 2018 Beam Communications. All rights reserved.
//

import UIKit

class MainTableViewController: UITableViewController {
	
	fileprivate static var context = "ESRefreshKVOContext"
	fileprivate static let offsetKeyPath = "contentOffset"
	fileprivate static let contentSizeKeyPath = "contentSize"
	
	let refreshView: UIView = UIView(frame: CGRect.zero)
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshView.backgroundColor = UIColor.red
		tableView.addSubview(refreshView)
		
		tableView.addObserver(self, forKeyPath: MainTableViewController.offsetKeyPath, options: [.initial, .new], context: &MainTableViewController.context)
		tableView.addObserver(self, forKeyPath: MainTableViewController.contentSizeKeyPath, options: [.initial, .new], context: &MainTableViewController.context)
	}
	
	// MARK: - Table view data source
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 0
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		return 0
	}
	
	var wasDragged: Bool = false
	var isExpanded: Bool = false
	
	override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if context == &MainTableViewController.context {
			guard let scrollView = object as? UIScrollView else {
				return
			}
			guard scrollView.isUserInteractionEnabled && !scrollView.isHidden else {
				return
			}
			
			// This will give me the height to be used for the header view :)
			let actualOffset = (scrollView.contentOffset.y * -1) - scrollView.safeAreaInsets.top

			// If we're expanded and offset is less then 0, we want to keep
			// the height of the view, so it becomes "sticky"
			if isExpanded && actualOffset < 0 {
				let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y
				refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: 100)
			} else if actualOffset > 0 {
				// The scrollview is been pulled down, beyond it's "0" point
				// Calculate a y position which will place the view at the "top" of the scroll view
				let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y
				// Calculate the desired height based on the expanded state.
				// If the view is already expanded, then we want to allow it to "grow" beyond its
				// desired height, but not shrink.
				// If it's not expanded, then we can allow it to shrink...
				let height = isExpanded ? (actualOffset < 100 ? 100 : actualOffset) : actualOffset
				refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: height)
				defer {
					wasDragged = scrollView.isDragging
				}
				// Was the view previously been dragged, and was it dragged beyon our "desired" height?
				if wasDragged && !scrollView.isDragging && actualOffset >= 100 {
					// This can be used to animate the view open as well :)
					// Set the content inset to accomidate the view
					// Need to take into consideration the existing inset
					scrollView.bringSubviewToFront(refreshView)
					UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
						scrollView.contentInset.top += 100
					}) { (_) in
						self.isExpanded = true
					}
				}
			}
		}
	}
}
