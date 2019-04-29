//
//  StandartExecutor.swift
//  
//
//  Created by Alexander Naumov on 10/10/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import When

public struct StandartExecutor {
    public static func cancelTask(_ task: TaskType...) -> (@escaping CancelTaskAction) -> Void {
        return { task.forEach($0) }
    }
    public static func callEmptyProvider<R>(finalAction: @escaping ActionCreator<Result<R>>) -> (ProviderPR<R>, @escaping DispatchAction) -> Void {
        return { provider, dispatch in
            provider().always { dispatch(finalAction($0)) }
        }
    }
    public static func callProviderWithActionValue<V, R>(finalAction: @escaping ActionCreator<Result<R>>) -> (ProviderVPR<V, R>, @escaping DispatchAction, ActionValue<V>) -> Void {
        return { provider, dispatch, action in
            provider(action.value).always { dispatch(finalAction($0)) }
        }
    }
}
