import Hummingbird

// MARK: - Speech Submission Routes

func registerHTTPSpeechRoutes(
    on router: Router<BasicRequestContext>,
    configuration: HTTPConfig,
    host: ServerHost
) {
    router.post("speech/live") { request, context -> Response in
        let payload = try await request.decode(as: SpeakRequestPayload.self, context: context)
        let requestID = try await host.queueSpeechLive(
            text: payload.text,
            profileName: payload.profileName,
            textProfileName: payload.textProfileName,
            normalizationContext: try payload.normalizationContext(),
            sourceFormat: try payload.sourceFormatModel()
        )
        return try buildAcceptedRequestResponse(request: request, configuration: configuration, requestID: requestID)
    }

    router.post("speech/files") { request, context -> Response in
        let payload = try await request.decode(as: SpeakRequestPayload.self, context: context)
        let requestID = try await host.queueSpeechFile(
            text: payload.text,
            profileName: payload.profileName,
            textProfileName: payload.textProfileName,
            normalizationContext: try payload.normalizationContext(),
            sourceFormat: try payload.sourceFormatModel()
        )
        return try buildAcceptedRequestResponse(request: request, configuration: configuration, requestID: requestID)
    }

    router.post("speech/batches") { request, context -> Response in
        let payload = try await request.decode(as: GenerateBatchRequestPayload.self, context: context)
        let requestID = try await host.queueSpeechBatch(
            items: try payload.items.map { try $0.model() },
            profileName: payload.profileName
        )
        return try buildAcceptedRequestResponse(request: request, configuration: configuration, requestID: requestID)
    }
}
