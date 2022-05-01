//------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Logger project, released under the MIT License.                //
// See LICENSE file or go to https://github.com/jongpie/NebulaLogger for full license details.    //
//------------------------------------------------------------------------------------------------//

/**
 * @group Log Management
 * @description Controller class for lwc `loggerSettings`, used to manage records in `LoggerSettings__c`
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.ExcessivePublicCount')
public without sharing class LoggerSettingsController {
    // Data methods
    /**
     * @description Indicates if the current user has access to modify `LoggerSettings__c` records,
     *              based on either object-level access on `LoggerSettings__c`, or access to the custom permission `CanModifyLoggerSettings`
     * @return   return description
     */
    @AuraEnabled(cacheable=true)
    public static Boolean canUserModifyLoggerSettings() {
        return Schema.LoggerSettings__c.SObjectType.getDescribe().isUpdateable() == true ||
            FeatureManagement.checkPermission('CanModifyLoggerSettings') == true;
    }

    /**
     * @description Returns all of the `List<PicklistOption>` used in the frontend for displaying certain text fields as picklist fields
     * @return   The instance of `LoggerSettingsPicklistOptions`, containing all picklist options for any fields treated as picklists
     */
    @AuraEnabled(cacheable=true)
    public static LoggerSettingsPicklistOptions getPicklistOptions() {
        LoggerSettingsPicklistOptions loggerSettingsPicklistOptions = new LoggerSettingsPicklistOptions();
        loggerSettingsPicklistOptions.loggingLevelOptions = getLoggingLevelOptions();
        loggerSettingsPicklistOptions.saveMethodOptions = getSaveMethodOptions();
        loggerSettingsPicklistOptions.setupOwnerTypeOptions = getSetupOwnerTypeOptions();
        loggerSettingsPicklistOptions.shareAccessLevelOptions = getShareAccessLevelOptions();
        return loggerSettingsPicklistOptions;
    }

    /**
     * @description Returns all existing `LoggerSettings__c` records as instances of `SettingsRecordResult`
     * @return   The list of existing records
     */
    @AuraEnabled
    public static List<SettingsRecordResult> getRecords() {
        List<SettingsRecordResult> settingsRecordResults = new List<SettingsRecordResult>();
        List<Id> setupOwnerIds = new List<Id>();
        for (LoggerSettings__c settingsRecord : queryLoggerSettings()) {
            SettingsRecordResult settingsRecordResult = new SettingsRecordResult();
            settingsRecordResult.setupOwnerType = getSetupOwnerType(settingsRecord);
            settingsRecordResult.setupOwnerName = settingsRecord.SetupOwner.Name;
            settingsRecordResult.createdByUsername = settingsRecord.CreatedBy.Username;
            settingsRecordResult.lastModifiedByUsername = settingsRecord.LastModifiedBy.Username;
            settingsRecordResult.record = settingsRecord;
            settingsRecordResults.add(settingsRecordResult);

            setupOwnerIds.add(settingsRecord.SetupOwnerId);
        }

        Map<Id, String> setupOwnerIdToName = querySetupOwnerNames(setupOwnerIds);
        for (SettingsRecordResult settingsRecordResult : settingsRecordResults) {
            if (setupOwnerIdToName.containsKey((settingsRecordResult.record.SetupOwnerId)) == true) {
                settingsRecordResult.setupOwnerName = setupOwnerIdToName.get(settingsRecordResult.record.SetupOwnerId);
            }
        }

        settingsRecordResults.sort();
        return settingsRecordResults;
    }

    /**
     * @description Creates a new, unsaved `LoggerSettings__c` record
     * @return   A new `LoggerSettings__c` record, with all fields populated with default values
     */
    @AuraEnabled(cacheable=true)
    public static LoggerSettings__c createRecord() {
        return (LoggerSettings__c) Schema.LoggerSettings__c.SObjectType.newSObject(null, true);
    }

    /**
     * @description Upserts the specified `LoggerSettings__c` record
     * @param  settingsRecord The record to save
     */
    @AuraEnabled
    public static void saveRecord(LoggerSettings__c settingsRecord) {
        try {
            if (canUserModifyLoggerSettings() == true) {
                upsert settingsRecord;
            }
        } catch (Exception ex) {
            throw createAuraHandledException(ex);
        }
    }

    /**
     * @description Deletes the specified `LoggerSettings__c` record
     * @param  settingsRecord The record to delete
     */
    @AuraEnabled
    public static void deleteRecord(LoggerSettings__c settingsRecord) {
        try {
            if (canUserModifyLoggerSettings() == true) {
                delete settingsRecord;
            }
        } catch (Exception ex) {
            throw createAuraHandledException(ex);
        }
    }

    // Setup Owner methods
    /**
     * @description Returns the `Organization` record for the current environment
     * @return   The current environment's `Organization` record
     */
    @AuraEnabled(cacheable=true)
    public static Organization getOrganization() {
        return [SELECT Id, Name FROM Organization];
    }

    /**
     * @description searchForSetupOwner description
     * @param  setupOwnerType The object to search (`Profile` or `User`)
     * @param  searchTerm     The search term to use when searching records
     * @return                The list of `SetupOwnerSearchResult`, based on any matching SObject records
     */
    @AuraEnabled
    public static List<SetupOwnerSearchResult> searchForSetupOwner(String setupOwnerType, String searchTerm) {
        try {
            searchTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            List<SetupOwnerSearchResult> searchResults = new List<SetupOwnerSearchResult>();
            switch on setupOwnerType {
                when 'Profile' {
                    for (Profile matchingProfile : [SELECT Id, Name, UserLicense.Name FROM Profile WHERE Name LIKE :searchTerm ORDER BY Name]) {
                        SetupOwnerSearchResult result = new SetupOwnerSearchResult();
                        result.recordId = matchingProfile.Id;
                        result.label = matchingProfile.Name;
                        result.secondaryLabel = 'License: ' + matchingProfile.UserLicense.Name;
                        result.icon = 'utility:profile';
                        searchResults.add(result);
                    }
                }
                when 'User' {
                    for (User matchingUser : [
                        SELECT Id, Name, Username, SmallPhotoUrl
                        FROM User
                        WHERE Name LIKE :searchTerm OR Username LIKE :searchTerm
                        ORDER BY Username
                    ]) {
                        SetupOwnerSearchResult result = new SetupOwnerSearchResult();
                        result.recordId = matchingUser.Id;
                        result.label = matchingUser.Username;
                        result.secondaryLabel = 'Name: ' + matchingUser.Name;
                        result.icon = 'standard:people';
                        result.image = matchingUser.SmallPhotoUrl;
                        searchResults.add(result);
                    }
                }
                when else {
                    throw new IllegalArgumentException('Invalid SetupOwnerType: ' + setupOwnerType);
                }
            }
            return searchResults;
        } catch (Exception ex) {
            throw createAuraHandledException(ex);
        }
    }

    private static AuraHandledException createAuraHandledException(Exception ex) {
        AuraHandledException auraHandledException = new AuraHandledException(ex.getMessage());
        auraHandledException.setMessage(ex.getMessage());
        return auraHandledException;
    }

    private static List<PicklistOption> getLoggingLevelOptions() {
        List<PicklistOption> picklistOptions = initializePicklistOptions();
        for (Integer i = LoggingLevel.values().size() - 1; i > 0; i--) {
            LoggingLevel currentLoggingLevel = LoggingLevel.values().get(i);

            if (currentLoggingLevel == LoggingLevel.NONE || currentLoggingLevel == LoggingLevel.INTERNAL) {
                continue;
            }

            PicklistOption picklistOption = new PicklistOption();
            picklistOption.label = currentLoggingLevel.name();
            picklistOption.value = currentLoggingLevel.name();

            picklistOptions.add(picklistOption);
        }
        return picklistOptions;
    }

    private static List<PicklistOption> getSaveMethodOptions() {
        List<PicklistOption> picklistOptions = initializePicklistOptions();
        for (Logger.SaveMethod saveMethod : Logger.SaveMethod.values()) {
            PicklistOption picklistOption = new PicklistOption();
            picklistOption.label = saveMethod.name();
            picklistOption.value = saveMethod.name();

            picklistOptions.add(picklistOption);
        }
        return picklistOptions;
    }

    private static List<PicklistOption> getSetupOwnerTypeOptions() {
        List<PicklistOption> picklistOptions = initializePicklistOptions();
        List<String> optionNames = new List<String>{ 'Organization', 'Profile', 'User' };
        for (String optionName : optionNames) {
            PicklistOption picklistOption = new PicklistOption();
            picklistOption.label = optionName;
            picklistOption.value = optionName;

            picklistOptions.add(picklistOption);
        }
        return picklistOptions;
    }

    private static List<PicklistOption> getShareAccessLevelOptions() {
        List<PicklistOption> picklistOptions = initializePicklistOptions();
        for (Schema.PicklistEntry picklistEntry : Schema.Log__Share.AccessLevel.getDescribe().getPicklistValues()) {
            // The 'All' access level is an internal value and can't be granted
            // Source: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm
            if (picklistEntry.value == 'All') {
                continue;
            }

            PicklistOption picklistOption = new PicklistOption();
            picklistOption.label = picklistEntry.value;
            picklistOption.value = picklistEntry.value;

            picklistOptions.add(picklistOption);
        }
        return picklistOptions;
    }

    private static List<PicklistOption> initializePicklistOptions() {
        PicklistOption emptyPicklistOption = new PicklistOption();
        emptyPicklistOption.label = '--None--';
        emptyPicklistOption.value = '';
        List<PicklistOption> picklistOptions = new List<PicklistOption>();
        picklistOptions.add(emptyPicklistOption);
        return picklistOptions;
    }

    private static String getSetupOwnerType(LoggerSettings__c settingsRecord) {
        String setupOwnerType;
        switch on settingsRecord.SetupOwner.Type {
            when '00D' {
                setupOwnerType = 'Organization';
            }
            when '00e' {
                setupOwnerType = 'Profile';
            }
            when else {
                setupOwnerType = settingsRecord.SetupOwner.Type;
            }
        }
        return setupOwnerType;
    }

    private static List<LoggerSettings__c> queryLoggerSettings() {
        List<String> fieldNames = new List<String>(Schema.LoggerSettings__c.SObjectType.getDescribe().fields.getMap().keySet());
        fieldNames.add('CreatedBy.Username');
        fieldNames.add('LastModifiedBy.Username');
        fieldNames.add('SetupOwner.Name');
        fieldNames.add('SetupOwner.Type');
        String query = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + Schema.LoggerSettings__c.SObjectType;
        return (List<LoggerSettings__c>) Database.query(String.escapeSingleQuotes(query));
    }

    private static Map<Id, String> querySetupOwnerNames(List<Id> setupOwnerIds) {
        Map<Id, String> setupOwnerIdToName = new Map<Id, String>();
        for (Profile profile : [SELECT Id, Name FROM Profile WHERE Id IN :setupOwnerIds]) {
            setupOwnerIdToName.put(profile.Id, profile.Name);
        }
        for (User user : [SELECT Id, Username FROM User WHERE Id IN :setupOwnerIds]) {
            setupOwnerIdToName.put(user.Id, user.Username);
        }
        return setupOwnerIdToName;
    }

    /**
     * @description Inner class for returning all custom `List<PicklistOption>` in a single Apex method call
     */
    public class LoggerSettingsPicklistOptions {
        @AuraEnabled
        public List<PicklistOption> loggingLevelOptions;
        @AuraEnabled
        public List<PicklistOption> saveMethodOptions;
        @AuraEnabled
        public List<PicklistOption> setupOwnerTypeOptions;
        @AuraEnabled
        public List<PicklistOption> shareAccessLevelOptions;
    }

    /**
     * @description Inner DTO class for picklist options since Schema.PicklistEntry isn't supported for aura-enabled methods
     */
    public class PicklistOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;
    }

    /**
     * @description Inner class used for sorting LoggerSettings__c, used for 3 reasons:
     *      1. Trying to sort in SOQL on SetupOwner.Type, SetupOwner.Name results in only user-specific records being returned (no idea why - seems like a bug)
     *      2. Records tied to profiles do not return the actual profile name in SetupOwner.Name - example: System Admin returns as 'PT1' in query results
     *      3. Records tied to the org or profiles return unhelpful values in SetupOwner.Type - org returns '00D', profiles return '00e'
     */
    public class SettingsRecordResult implements Comparable {
        @AuraEnabled
        public String setupOwnerType;
        @AuraEnabled
        public String setupOwnerName;
        @AuraEnabled
        public String createdByUsername;
        @AuraEnabled
        public String lastModifiedByUsername;
        @AuraEnabled
        public LoggerSettings__c record;

        /**
         * @description Implements sorting logic for the `Comparable` interface
         * @param  compareTo The object to compare to when sorting the current item
         * @return           The sorting result
         */
        public Integer compareTo(Object compareTo) {
            SettingsRecordResult that = (SettingsRecordResult) compareTo;
            if (this.getCompositeName() == that.getCompositeName()) {
                return 0;
            } else if (this.getCompositeName() > that.getCompositeName()) {
                return 1;
            } else {
                return -1;
            }
        }

        private String getCompositeName() {
            return this.setupOwnerType + '.' + this.setupOwnerName;
        }
    }

    /**
     * @description Inner class used for returning search results for `Profile` and `User` records
     */
    public class SetupOwnerSearchResult {
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String secondaryLabel;
        @AuraEnabled
        public String icon;
        @AuraEnabled
        public String image;
    }
}