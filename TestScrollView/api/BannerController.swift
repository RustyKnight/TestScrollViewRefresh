//
//  BannerController.swift
//  TestScrollView
//
//  Created by Shane Whitehead on 30/11/18.
//  Copyright © 2018 Beam Communications. All rights reserved.
//

import Foundation
import UIKit

// Great name 🙄
// Basically this provides an observer that is notified when the
// "expandable" controller is updated, as a percentage.  The delta
// may be greater then 1, but should never be less then zero
public protocol ExpandableController {
	func expanded(by delta: CGFloat)
}

public protocol RefreshableController: ExpandableController {
	var view: UIView { get }
	var desiredHeight: CGFloat { get }
	
	func beginRefreshing()
	func endRefreshing()
}

public typealias Complition = () -> Void

class Snapshot {
  let insetTop: CGFloat
  
  init(insetTop: CGFloat) {
    self.insetTop = insetTop
  }
}

public class BannerController: NSObject {
	
	enum BannerState {
		case open
		case closed
    
    case relaxing
		
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
	
	open var refreshController: RefreshableController? {
		didSet {
			uninstallRefresherIfNeeded(oldValue)
			installRefresherIfNeeded()
		}
	}
	
	// I was hoping to avoid this...
	weak var scrollView: UIScrollView?
	
  var animationDuration: TimeInterval = 0.5
  
	public func install(on scrollView: UIScrollView) {
		self.scrollView = scrollView
    
//    scrollView.panGestureRecognizer.addTarget(self, action: #selector(scrollViewPanned))
    
		scrollView.addObserver(self, forKeyPath: KeyPath.contentOffset.rawValue, options: [.initial, .new], context: &BannerController.context)
		scrollView.addObserver(self, forKeyPath: KeyPath.contentSize.rawValue, options: [.initial, .new], context: &BannerController.context)
		
		uninstallRefresherIfNeeded(refreshController)
		installRefresherIfNeeded()
	}
	
	func uninstallRefresherIfNeeded(_ controller: RefreshableController?) {
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
  
//  @objc func scrollViewPanned(_ geasture: UIPanGestureRecognizer) {
//    if geasture.state == .began {
//      print("began")
//    } else if geasture.state == .ended {
//      print("ended")
//    } else if geasture.state == .cancelled {
//      print("cancelled")
//    } else if geasture.state == .changed {
//      print("changed")
//    } else if geasture.state == .failed {
//      print("failed")
//    } else if geasture.state == .failed {
//      print("failed")
//    } else if geasture.state == .recognized {
//      print("recognized")
//    }
//  }

	// Determines if the "scroll view" was previously been dragged
	var wasDragged: Bool = false
  var lastOffset: CGFloat?

	func update(_ refreshController: RefreshableController, in scrollView: UIScrollView) {
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
			refreshController.expanded(by: progress)
			
		} else if actualOffset > 0 && !refreshState.isOpen && refreshState != .relaxing {
      // While been dragged, keep track of the last offset height, as this
      // changes dramatically when released
      if scrollView.isDragging {
        lastOffset = actualOffset
      }

      // Has the user stopped dragging and does the view need to be "relaxed" back into position.
      // Essentially the user needs to drag beyond the desired height of the view before it becomes
      // sticky
			if !refreshState.isOpen && wasDragged && !scrollView.isDragging && actualOffset >= desiredHeight {
        // Relaxing into position, stops some of the other code from
        // interacting while the relax animation is running
        refreshState = .relaxing

        // Set the frame size based on the last offset position.  This is an attempt to stop the UI from
        // flickering as the actualOffset is not the same as the offset when the user released the view
        refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: lastOffset ?? actualOffset)
        lastOffset = nil

        self.beginRefreshing()
      } else {
        // The scrollview is been pulled down, beyond it's "0" point
        //let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y
        // Calculate the desired height based on the expanded state.
        // If the view is already expanded, then we want to allow it to "grow" beyond its
        // desired height, but not shrink.
        // If it's not expanded, then we can allow it to shrink...
        let height = refreshState.isOpen ? (actualOffset < desiredHeight ? desiredHeight : actualOffset) : actualOffset
        refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: height)
        
        let progress = height / desiredHeight
        
        refreshController.expanded(by: progress)
      }
		}
	}
  
  // This basically distills the process of generating the
  // expansion callback so that both expanding and collapsing run through the same process
  func size(controller: RefreshableController,
            scrollView: UIScrollView,
            snapShot: Snapshot,
            range: ClosedRange<CGFloat>,
            at progress: Double,
            reversed: Bool = false) {
    let desiredHeight = controller.desiredHeight

    let value = range.value(at: progress, reversed: reversed)
    let delta = value / desiredHeight
    
    let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y

    controller.view.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: value)

    // Need to set this first, otherwise it will effect the size of the view
    scrollView.contentInset.top = snapShot.insetTop + value

    controller.view.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: value)
    controller.expanded(by: delta)
    
  }

  public func beginRefreshing(then: Complition? = nil) {
		guard let scrollView = scrollView, let controller = refreshController, !refreshState.isOpen else {
			return
		}
    
		let refreshView = controller.view
		let desiredHeight = controller.desiredHeight
    let startHeight = refreshView.frame.height

    // Snapshot the current state
    let snapShot = Snapshot(insetTop: scrollView.contentInset.top)
    // Set the insets to the current height of the view
    scrollView.contentInset.top = startHeight
    
    // Stop the scroll view from bouncing, to help the animation run more smoothly
    let shouldBounce = scrollView.bounces
    scrollView.bounces = false

    // Calculate the y offset for the view
		let yPos = scrollView.safeAreaInsets.top + scrollView.contentOffset.y
    
    // The frame size is set here as beginRefresh may be called externally
		scrollView.bringSubviewToFront(refreshView)
    refreshView.frame = CGRect(x: 0, y: yPos, width: scrollView.bounds.width, height: startHeight)

    // The expected range of change
    let range: ClosedRange<CGFloat> = min(startHeight, desiredHeight)...max(startHeight, desiredHeight)

//    let delay = DispatchTime.now() + .seconds(5)
//    DispatchQueue.main.asyncAfter(deadline: delay) {
    
      let animator = DurationAnimator(duration: self.animationDuration, timingFunction: .easeInEaseOut, ticker: { (animator, progress) in
        // Here we determine if the range should be reversed or not based on the difference between the
        // start and end of the range
        self.size(controller: controller,
                  scrollView: scrollView,
                  snapShot: snapShot,
                  range: range,
                  at: progress,
                  reversed: startHeight > desiredHeight)
      }) { (_) in
        self.size(controller: controller,
                  scrollView: scrollView,
                  snapShot: snapShot,
                  range: range,
                  at: 1.0,
                  reversed: startHeight > desiredHeight)
        controller.beginRefreshing()
        self.refreshState = .open
        // reset the bounce
        scrollView.bounces = shouldBounce
        then?()
      }
      animator.start()
//    }
		
	}
	
	public func endRefreshing() {
		guard let scrollView = scrollView, let controller = refreshController, refreshState.isOpen else {
			return
		}
		let refreshView = controller.view
		//let desiredHeight = controller.desiredHeight

		// Set the content inset to accomidate the view
		// Need to take into consideration the existing inset
		scrollView.bringSubviewToFront(refreshView)
		controller.endRefreshing()
    
    let frame = refreshView.frame
    // The expected range over which the frame will change
    let range: ClosedRange<CGFloat> = CGFloat(0)...frame.height
    
    let snapShot = Snapshot(insetTop: scrollView.contentInset.top - controller.desiredHeight)

    let animator = DurationAnimator(duration: animationDuration, timingFunction: .easeInEaseOut, ticker: { (animator, progress) in
      // This is always going to be reversed, as we should be going from big to small
      self.size(controller: controller,
                scrollView: scrollView,
                snapShot: snapShot,
                range: range,
                at: progress,
                reversed: true)
      scrollView.contentInset.top = refreshView.frame.height
    }) { (_) in
      self.size(controller: controller,
                scrollView: scrollView,
                snapShot: snapShot,
                range: range,
                at: 1.0,
                reversed: true)
      self.refreshState = .closed
    }
    animator.start()
	}
}
