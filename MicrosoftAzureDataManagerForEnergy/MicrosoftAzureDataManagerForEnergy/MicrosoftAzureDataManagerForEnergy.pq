// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

[Version="1.0.0"]
section MicrosoftAzureDataManagerForEnergy;

redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html"; // Must be a platform that supports PKCE (Single Page Application)
logoutUri = "https://login.microsoftonline.com/logout.srf";
pageSize = 100;

[DataSource.Kind="MicrosoftAzureDataManagerForEnergy", Publish="MicrosoftAzureDataManagerForEnergy.Publish"]
shared MicrosoftAzureDataManagerForEnergy.Search = Value.ReplaceType(MicrosoftAzureDataManagerForEnergyImpl, MicrosoftAzureDataManagerForEnergyType);

MicrosoftAzureDataManagerForEnergyType = type function (
    serviceName as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("serviceNameFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("serviceNameFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("serviceNameSampleValues")}
    ]),
    dataPartition as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("dataPartitionFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("dataPartitionFieldDescription"),
        Documentation.SampleValues = {Extension.LoadString("dataPartitionSampleValues")}
    ]),
    resourceId as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("resourceIdFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("resourceIdFieldDescription"),
        Documentation.SampleValues = {"fb82bc98-a537-4c2b-a4ed-cf7c53eed5f9"}
    ]),
    kind as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("kindFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("kindFieldDescription"),
        Documentation.SampleValues = {"osdu:wks:master-data--Well:1.0.0"}
    ]),
    query as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("queryFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("queryFieldDescription"),
        Documentation.SampleValues = {"*"}
    ]),
    optional limit as (type number meta [
        Documentation.FieldCaption = Extension.LoadString("limitFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("limitFieldDescription"),
        Documentation.SampleValues = {"2000"}
    ]),
    optional returnedFields as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("returnedFieldsFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("returnedFieldsFieldDescription"),
        Documentation.SampleValues = {"""data.FacilityName"", ""data.Source"""}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("documentationName"),
        Documentation.LongDescription = Extension.LoadString("documentationLongDescription"),
        Documentation.Examples = {[
            Description = Extension.LoadString("exampleDescription"),
            Code = "MicrosoftAzureDataManagerForEnergy.Search(""platform4321"", ""opendes"", ""fb82bc98-a537-4c2b-a4ed-cf7c53eed5f9"", ""osdu:wks:master-data--Well:1.0.0"", ""*"", 2, null)",
            Result = Extension.LoadString("exampleResult")
        ]}
    ];

MicrosoftAzureDataManagerForEnergyImpl = (
                                      serviceName as text, 
                                      dataPartition as text,
                                      resourceId as text,
                                      kind as text, 
                                      query as text,
                                      optional limit as number, 
                                      optional returnedFields as text) =>
    let
        validLimit = ValidateLimit(limit),
        endpoint = BuildEndpoint(serviceName),
        results = GetSearchResults(endpoint, dataPartition, kind, query, validLimit, returnedFields),
        totalRecordCount = GetTotalRecordCount(endpoint, dataPartition, kind, query),
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {kind, kind, Record.ToTable([Count = totalRecordCount, Records = results]), "Table", "Table", true}
            }
        ),
        navigationTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navigationTable;

ValidateLimit = (limit) => 
    let
        validLimit = 
            if limit = null or limit >= 0 then 
                limit
            else
                error Extension.LoadString("errorNegativeLimit")
    in 
        validLimit;

BuildEndpoint = (serviceName) => "https://" & serviceName & ".energy.azure.com/api/search/v2/query_with_cursor";
    
GetTotalRecordCount = (endpoint as text,
                        dataPartition as text,
                        kind as text, 
                        query as text) as number => 
    let
        startPosition = 0,
        limit = 1,
        runningCount = 0,
        page = GetSearchResultPage(endpoint, dataPartition, kind, query, runningCount, "", limit)
    in
        Value.Metadata(page)[totalNumberOfRecords];

GetSearchResults = (endpoint as text,
                    dataPartition as text,
                    kind as text, 
                    query as text,
                    optional limit as number, 
                    optional returnedFields as text) =>
    Table.GenerateByPage(
        (previous) =>
            let
                cursor = if previous = null then ""
                     else Value.Metadata(previous)[cursor],
                runningCountOfRetrievedRecords = if previous = null then 0
                    else Value.Metadata(previous)[runningCountOfRetrievedRecords],
                table = if RetrievedAllPages(previous, limit) then null // Returning null stops the pagination function
                     else GetSearchResultPage(endpoint, dataPartition, kind, query, runningCountOfRetrievedRecords, cursor, limit, returnedFields)
            in
                table);

GetSearchResultPage = (endpoint as text,
                        dataPartition as text,
                        kind as text, 
                        query as text,
                        runningCountOfRetrievedRecords as number,
                        optional cursor as text, 
                        optional limit as number, 
                        optional returnedFields as text) =>
    let
        adjustedLimit = AdjustPageSizeDependingOnUsersLimit(runningCountOfRetrievedRecords, limit),
        body = GetQueryString(kind, query, cursor, adjustedLimit, returnedFields),
        results = Json.Document(Web.Contents(endpoint,[
            Headers = [#"Content-Type"="application/json", #"data-partition-id"=dataPartition],
            Content = Text.ToBinary(body),
            IsRetry = true
       ])),
       totalNumberOfRecords = results[totalCount],
       returnedCursor = GetReturnedCursor(results),
       records = GetSubsetOfRecordsIfNecessary(results[results], runningCountOfRetrievedRecords, limit),
       updatedCount = List.Count(records) + runningCountOfRetrievedRecords,
       resultTable = Table.FromList(records, Splitter.SplitByNothing(), {"Records"}, null, ExtraValues.Error)
    in
       resultTable meta [cursor = returnedCursor, totalNumberOfRecords = totalNumberOfRecords, runningCountOfRetrievedRecords = updatedCount];

GetSubsetOfRecordsIfNecessary = (records as list, runningCountOfRetrievedRecords as number, optional limit as number) => 
    let
        numberOfReturnedRecords = List.Count(records),
        endingIndex = limit - runningCountOfRetrievedRecords,
        updatedRecords = if not (limit = null) and not (limit = 0) and (runningCountOfRetrievedRecords + numberOfReturnedRecords > limit) then // User specified limit and keeping all returned records puts the retreived record count over limit
                            List.Range(records, 0, endingIndex) // Get a range of records to prevent going over the user's limit
                         else
                            records
    in 
        updatedRecords;

GetReturnedCursor = (results as record) => 
    let
        returnedCursor = results[cursor]
    in
        returnedCursor;

RetrievedAllPages = (previousPage, optional limit as number) => 
    let 
        isFirstPage = if previousPage = null then true else false,
        collectedItems = Value.Metadata(previousPage)[runningCountOfRetrievedRecords],
        totalItems = Value.Metadata(previousPage)[totalNumberOfRecords],
        didRetrievedAll = 
            if isFirstPage then // We haven't retrieved any pages yet
                false
            else
                if collectedItems = totalItems then // Retrieved all records, regardless of user's limit
                    true
                else if not (limit = null) and collectedItems >= limit then // User specified limit and we retrieved that many records. Using >= comparison in case user specified 0 limit - Azure Data Manager for Energy will default to 10 in that case
                    true
                else // We have more records to retrieve beause we haven't retrieved them all yet, or we haven't reached the user's optional limit
                    false
    in
        didRetrievedAll;

AdjustPageSizeDependingOnUsersLimit = (runningCountOfRetrievedRecords as number, optional limit as number) as number =>
    let 
        adjustedLimit = 
            if limit = null then 
                pageSize
            else
                if pageSize > limit // User wants less than the page size
                    then limit  
                else if (runningCountOfRetrievedRecords + pageSize) > limit // Limit is more than the page size, but need a partial page to reach limit on the final page
                    then Number.Mod(limit - pageSize, pageSize) // Mod in case limit - page size is greater than page size
                else pageSize // Get an entire page
    in
        adjustedLimit;

MicrosoftAzureDataManagerForEnergy = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            resourceId = json[resourceId],
            serviceName = json[serviceName],
            dataPartition = json[dataPartition],
            kind = json[kind],
            query = json[query]
        in
            { "MicrosoftAzureDataManagerForEnergy.Search", serviceName, dataPartition, resourceId, kind, query },
    Authentication = [
        Aad = [
            AuthorizationUri = (dataSourcePath) => "https://login.microsoftonline.com/common/oauth2/authorize",
            Resource = (dataSourcePath) => Json.Document(dataSourcePath)[resourceId]
        ]
    ],
    Label = Extension.LoadString("dataSourceLabel")
];

MicrosoftAzureDataManagerForEnergy.Publish = [
    Beta = true,
    Category = "Azure",
    ButtonText = { Extension.LoadString("buttonTitle"), Extension.LoadString("buttonHelp") },
    LearnMoreUrl = "https://learn.microsoft.com/azure/energy-data-services/",
    SourceImage = MicrosoftAzureDataManagerForEnergy.Icons,
    SourceTypeImage = MicrosoftAzureDataManagerForEnergy.Icons
];

MicrosoftAzureDataManagerForEnergy.Icons = [
    Icon16 = { Extension.Contents("MicrosoftAzureDataManagerForEnergy16.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy20.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy24.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy32.png") },
    Icon32 = { Extension.Contents("MicrosoftAzureDataManagerForEnergy32.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy40.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy48.png"), Extension.Contents("MicrosoftAzureDataManagerForEnergy64.png") }
];

ValueNumber.IfNull = (a, b, fieldname) => if a <> null then ",""" & fieldname & """: " & Number.ToText(a) else b;

ValueText.IfNullOrEmpty = (a, b, fieldname) => if (a <> null and a <> "") then  ",""" & fieldname & """: """ & a & """" else b;

ValueText.IfNullOrEmptyAsList = (a, b, fieldname) => if (a <> null and a <> "") then  ",""" & fieldname & """: [" & a & "]" else b;
 
GetQueryString = (kind as text, query as text, cursor as text, optional limit as number, optional returnedFields as text) as text =>
    let
        queryText = "{""kind"": """ & kind & """,""query"": """ & query & """" & ValueNumber.IfNull(limit, "", "limit") & ValueText.IfNullOrEmpty(cursor, "", "cursor") & ValueText.IfNullOrEmptyAsList(returnedFields, "", "returnedFields") & "}"
    in
        queryText;

Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;