import Hummingbird

// MARK: - Generation Routes

func registerHTTPGenerationRoutes(
    on router: Router<BasicRequestContext>,
    host: ServerHost
) {
    router.get("generation/queue") { _, _ -> QueueSnapshotResponse in
        await host.generationQueueSnapshot()
    }

    router.get("generation/jobs") { _, _ -> Response in
        try encodeJSONResponse(try await host.listGenerationJobs(), status: .ok)
    }

    router.get("generation/jobs/:job_id") { _, context -> Response in
        let jobID = try context.parameters.require("job_id")
        return try encodeJSONResponse(try await host.generationJob(id: jobID), status: .ok)
    }

    router.delete("generation/jobs/:job_id") { _, context -> Response in
        let jobID = try context.parameters.require("job_id")
        return try encodeJSONResponse(try await host.expireGenerationJob(id: jobID), status: .ok)
    }

    router.get("generation/files") { _, _ -> Response in
        try encodeJSONResponse(try await host.listGeneratedFiles(), status: .ok)
    }

    router.get("generation/files/:artifact_id") { _, context -> Response in
        let artifactID = try context.parameters.require("artifact_id")
        return try encodeJSONResponse(try await host.generatedFile(id: artifactID), status: .ok)
    }

    router.get("generation/batches") { _, _ -> Response in
        try encodeJSONResponse(try await host.listGeneratedBatches(), status: .ok)
    }

    router.get("generation/batches/:batch_id") { _, context -> Response in
        let batchID = try context.parameters.require("batch_id")
        return try encodeJSONResponse(try await host.generatedBatch(id: batchID), status: .ok)
    }
}
