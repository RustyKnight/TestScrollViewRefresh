//
//  DurationAnimator.swift
//  Animator
//
//  Created by Shane Whitehead on 24/8/18.
//  Copyright © 2018 KaiZen. All rights reserved.
//

import Foundation
import UIKit

public typealias DurationTicker = (DurationAnimator, Double) -> Void
public typealias AnimationCompleted = (Bool) -> Void

// MARK: DurationAnimation
// An animation with a specific time frame to run in
public protocol DurationAnimatorDelegate {
	func didTick(animation: DurationAnimator, progress: Double)
	func didComplete(animation: DurationAnimator, completed: Bool)
}

public class DurationAnimator: Animator {
  
  public enum Curve {
    case `default`
    case easeIn
    case easeInEaseOut
    case easeOut
    case linear

    var mediaTimingFunction: CAMediaTimingFunction {
      switch self {
      case .default: return CAMediaTimingFunction(name: .default)
      case .easeIn: return CAMediaTimingFunction(name: .easeIn)
      case .easeInEaseOut: return CAMediaTimingFunction(name: .easeInEaseOut)
      case .easeOut: return CAMediaTimingFunction(name: .easeOut)
      case .linear: return CAMediaTimingFunction(name: .linear)
      }
    }
  }
	
	public var delegate: DurationAnimatorDelegate?
	
	internal var duration: TimeInterval // How long the animation should play for
	internal var startedAt: Date? // When the animation was started
	
	internal var timingFunction: CAMediaTimingFunction?
	
	internal var rawProgress: Double {
		guard let startedAt = startedAt else {
			return 0.0
		}
		let runningTime = Date().timeIntervalSince(startedAt)
		return runningTime / duration
	}
	
	internal var progress: Double {
		let value = rawProgress
		guard let timingFunction = timingFunction else {
			return value
		}
		return timingFunction.value(atTime: value)
	}
	
	internal var ticker: DurationTicker?
  internal var completed: AnimationCompleted?
	
	public var repeats: Bool = false
	
  public init(duration: TimeInterval, timingFunction: Curve? = nil, ticker: DurationTicker? = nil, then: AnimationCompleted? = nil) {
		self.duration = duration
		self.timingFunction = timingFunction?.mediaTimingFunction
		self.ticker = ticker
    self.completed = then
		super.init()
	}
	
	override public func tick() {
		guard let startedAt = startedAt else {
			return
		}
		defer {
			if rawProgress >= 1.0 {
				if repeats {
					restart()
				} else {
					stop()
				}
			}
		}
		let progress = self.progress
		if let ticker = ticker {
			ticker(self, progress)
		}
		delegate?.didTick(animation: self, progress: progress)
	}
	
	override func didStart() {
		startedAt = Date()
	}
	
	override func didStop() {
    print("didStop")
		if let ticker = ticker {
			ticker(self, progress)
		}
    if let completed = completed {
      //, rawProgress >= 1.0
      print("call completed")
      completed(rawProgress >= 1.0)
    }
		delegate?.didComplete(animation: self, completed: rawProgress >= 1.0)
		startedAt = nil
		guard rawProgress >= 1.0, repeats else {
			return
		}
	}
	
	func restart() {
		stop()
		start()
	}
	
}
