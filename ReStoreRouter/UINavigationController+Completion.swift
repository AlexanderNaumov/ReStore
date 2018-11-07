//
//  UINavigationController.swift
//
//
//  Created by Alexander Naumov on 10.09.2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import UIKit

extension UINavigationController {
    public func pushViewController(_ viewController: UIViewController, animated: Bool, completion: @escaping () -> Void) {
        pushViewController(viewController, animated: animated)
        guard animated, let coordinator = transitionCoordinator else { completion(); return }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
    
    @discardableResult
    public func popViewController(animated: Bool, completion: @escaping () -> Void) -> UIViewController? {
        let vc = popViewController(animated: animated)
        guard animated, let coordinator = transitionCoordinator else { completion(); return vc }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
        return vc
    }
}
