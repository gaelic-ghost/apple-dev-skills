import Hummingbird
import HTTPTypes

// MARK: - Request Routes

func registerHTTPRequestRoutes(
    on router: Router<BasicRequestContext>,
    host: ServerHost
) {
    router.get("requests") { _, _ -> RequestListResponse in
        .init(requests: await host.jobSnapshots())
    }

    router.get("requests/:request_id") { _, context -> JobSnapshot in
        let requestID = try context.parameters.require("request_id")
        return try await host.jobSnapshot(id: requestID)
    }

    router.get("requests/:request_id/events") { _, context -> Response in
        let requestID = try context.parameters.require("request_id")
        let body = ResponseBody(
            asyncSequence: try await host.sseStream(for: requestID)
        )
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.connection] = "keep-alive"
        return Response(status: .ok, headers: headers, body: body)
    }
}
