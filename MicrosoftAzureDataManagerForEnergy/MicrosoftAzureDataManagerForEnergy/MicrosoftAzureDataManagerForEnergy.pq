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
    clientId as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("clientIdFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("clientIdFieldDescription"),
        Documentation.SampleValues = {"fb82bc98-a537-4c2b-a4ed-cf7c53eed5f9"}
    ]),
    tenantId as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("tentantIdFieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("tenantIdFieldDescription"),
        Documentation.SampleValues = {"4b12b551-b235-46b3-9f79-6a61adc75b6a"}
    ]),
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
            Code = "MicrosoftAzureDataManagerForEnergy.Search(""fb82bc98-a537-4c2b-a4ed-cf7c53eed5f9"", ""4b12b551-b235-46b3-9f79-6a61adc75b6a"", ""platform4321"", ""platform4321-opendes"", ""osdu:wks:master-data--Well:1.0.0"", ""*"", 2, null)",
            Result = Extension.LoadString("exampleResult")
        ]}
    ];

MicrosoftAzureDataManagerForEnergyImpl = (clientId as text, 
                                      tenantId as text, 
                                      serviceName as text, 
                                      dataPartition as text,
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
            clientId = json[clientId],
            tenantId = json[tenantId],
            serviceName = json[serviceName],
            dataPartition = json[dataPartition],
            kind = json[kind],
            query = json[query]
        in
            { "MicrosoftAzureDataManagerForEnergy.Search", clientId, tenantId, serviceName, dataPartition, kind, query },
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
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

Base64UrlEncode = (toConvert as binary) as text =>
	let
		encodedText = Binary.ToText(toConvert, BinaryEncoding.Base64)
	in
		Text.Remove(Text.Replace(Text.Replace(encodedText, "+", "-"), "/", "_"), "=");

CreateCodeChallenge = (codeVerifier as text) as text => 
    let 
        encodedText = Text.ToBinary(codeVerifier, TextEncoding.Ascii),
        challenge = Base64UrlEncode(Crypto.CreateHash(CryptoAlgorithm.SHA256, encodedText))
    in
        challenge;

GetScopes = (clientId as text) as text =>
    let
        scopes = "openid profile offline_access " & clientId & "/.default"
    in 
        scopes;

GetClientId = (queryParameters as text) as text => 
    let
        jsonQueryParameters = Json.Document(queryParameters),
        clientId = jsonQueryParameters[clientId]        
    in
        clientId;

GetAuthenticationBaseUrl = (queryParameters as text) as text => 
    let 
        jsonQueryParameters = Json.Document(queryParameters),
        tenantId = jsonQueryParameters[tenantId],
        authenticationBaseUrl = "https://login.microsoftonline.com/" & tenantId & "/oauth2/v2.0"
    in
        authenticationBaseUrl;

StartLogin = (dataSourcePath, state, display) =>
    let
        clientId = GetClientId(dataSourcePath),
        codeVerifier = Text.NewGuid() & Text.NewGuid(),
        AuthorizeUrl = GetAuthenticationBaseUrl(dataSourcePath) & "/authorize?" & Uri.BuildQueryString([
            client_id = clientId,
            response_type = "code",
            code_challenge_method = "S256",
            code_challenge = CreateCodeChallenge(codeVerifier),
            state = state,
            scope = GetScopes(clientId),
            redirect_uri = redirectUri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirectUri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = codeVerifier
        ];

FinishLogin = (clientApplication, dataSourcePath, context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                else
                    TokenMethod(dataSourcePath, parts[code], "authorization_code", context)
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");

Logout = (token) => logoutUri;

TokenMethod = (dataSourcePath, code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [ code = code ] else [ refresh_token = code ],
        query = codeVerifier & codeParameter & [
            client_id = GetClientId(dataSourcePath),
            grant_type = grant_type,
            redirect_uri = redirectUri
        ],
 
        // Set this if your API returns a non-2xx status for login failures
        ManualHandlingStatusCodes= {400},
        
        Response = Web.Contents(GetAuthenticationBaseUrl(dataSourcePath) & "/token", [
            Content = Text.ToBinary(Uri.BuildQueryString(query)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json",
                #"Origin" = ""
            ],
            ManualStatusHandling = ManualHandlingStatusCodes
        ]),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then 
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;
 
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