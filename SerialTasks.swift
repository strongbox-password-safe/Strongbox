//
//  SerialTasks.swift
//  Strongbox
//
//  Created by Strongbox on 22/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

actor SerialTasks<Success> {
    private var previousTask: Task<Success, Error>?

    func add(block: @Sendable @escaping () async throws -> Success) async throws -> Success {
        let task = Task { [previousTask] in
            let _ = await previousTask?.result
            return try await block()
        }
        previousTask = task
        return try await task.value
    }
}
