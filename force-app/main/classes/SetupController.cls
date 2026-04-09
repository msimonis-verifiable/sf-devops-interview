public with sharing class SetupController {
    @AuraEnabled
    public static Map<String, Object> getSetupConfiguration() {
        List<Setup_Configuration__mdt> configs = [
            SELECT ClientId__c, Environment__c
            FROM Setup_Configuration__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new AuraHandledException('No setup configuration found');
        }
        return new Map<String, Object>{
            'clientId' => configs[0].ClientId__c,
            'environment' => configs[0].Environment__c
        };
    }
}
