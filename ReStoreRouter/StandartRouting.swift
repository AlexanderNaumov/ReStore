//
//  StandartRouting.swift
//
//
//  Created by Alexander Naumov on 18/10/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import UIKit

public struct StandartRouting {
    public static func present(from: UIViewController, to: UIViewController, completion: @escaping () -> Void) {
        from.present(to, animated: true, completion: completion)
    }
    public static func dismiss(vc: UIViewController, completion: @escaping () -> Void) {
        vc.dismiss(animated: true, completion: completion)
    }
    public static func push(from: UIViewController, to: UIViewController, completion: @escaping () -> Void) {
        from.navigationController?.pushViewController(to, animated: true, completion: completion)
    }
    public static func pop(vc: UIViewController, completion: @escaping () -> Void) {
        vc.navigationController?.popViewController(animated: true, completion: completion)
    }
    public static func addChild(from: UIViewController, to: UIViewController, completion: @escaping () -> Void) {
        from.addChild(to)
        from.view.addSubview(to.view)
        to.view.translatesAutoresizingMaskIntoConstraints = false
        from.view.addConstraints(
            NSLayoutConstraint.constraints(withVisualFormat: "H:|[subview]|", metrics: nil, views: ["subview": to.view!]) +
            NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview]|", metrics: nil, views: ["subview": to.view!])
        )
        to.didMove(toParent: from)
        completion()
    }
    public static func removeFromParent(vc: UIViewController, completion: @escaping () -> Void) {
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        completion()
    }
}
