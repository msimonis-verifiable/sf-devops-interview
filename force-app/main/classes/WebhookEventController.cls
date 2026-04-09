@RestResource(urlMapping='/webhook/*')
global with sharing class WebhookEventController {
    @HttpPost
    global static void handleWebhookEvent() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            String eventType = (String) payload.get('eventType');
            processEvent(eventType, payload);
            res.statusCode = 200;
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(e.getMessage());
        }
    }

    private static void processEvent(String eventType, Map<String, Object> payload) {
        // Route to appropriate handler based on event type
        if (eventType == 'provider.updated') {
            // handle provider update
        } else if (eventType == 'license.verified') {
            // handle license verification
        }
    }
}
