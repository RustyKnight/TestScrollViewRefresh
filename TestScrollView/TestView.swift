//
//  TestView.swift
//  TestScrollView
//
//  Created by Shane Whitehead on 1/12/18.
//  Copyright © 2018 Beam Communications. All rights reserved.
//

import UIKit

class TestView: UIView, RefreshableController {
  
  @IBOutlet weak var label: UILabel!

  var view: UIView { return self }
  
  var desiredHeight: CGFloat = 100
  
  override func awakeFromNib() {
    super.awakeFromNib()
//    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    
    label.transform = CGAffineTransform(rotationAngle: -180.degreesToRadians)
    label.translatesAutoresizingMaskIntoConstraints = false
  }
  
  func beginRefreshing() {
  }
  
  func endRefreshing() {
  }
  
  func expanded(by delta: CGFloat) {
    let angle = -180 * (1.0 - delta)
    let scale = min(max(0, delta), 1.0)
    print("! \(delta) ~= \(angle) @ \(scale)")
    label.transform = CGAffineTransform(rotationAngle: angle.degreesToRadians).concatenating(CGAffineTransform(scaleX: scale, y: scale))
    setNeedsDisplay()
  }
  
  override class var requiresConstraintBasedLayout: Bool {
    return true
  }

  override var intrinsicContentSize: CGSize {
    return label.sizeThatFits(bounds.size)
  }
}

extension BinaryInteger {
  var degreesToRadians: CGFloat { return CGFloat(Int(self)) * .pi / 180 }
}

extension FloatingPoint {
  var degreesToRadians: Self { return self * .pi / 180 }
  var radiansToDegrees: Self { return self * 180 / .pi }
}
