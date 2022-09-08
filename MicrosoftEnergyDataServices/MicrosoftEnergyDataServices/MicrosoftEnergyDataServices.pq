// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
[Version="1.0.0"]
section MicrosoftEnergyDataServices;

redirectUri = "https://oauth.powerbi.com/views/oauthredirect.html"; // Must be a platform that supports PKCE
logoutUri = "https://login.microsoftonline.com/logout.srf";
pageSize = 100;
edsDefaultLimitSizeWhenZeroRequested = 10;

[DataSource.Kind="MicrosoftEnergyDataServices", Publish="MicrosoftEnergyDataServices.Publish"]
shared MicrosoftEnergyDataServices.Contents = (clientId as text, 
                                      tenantId as text, 
                                      endpoint as text, 
                                      dataPartition as text,
                                      kind as text, 
                                      query as text,
                                      optional limit as number, 
                                      optional returnedFields as text) =>
    let
        results = GetSearchResults(endpoint, dataPartition, kind, query, limit, returnedFields),
        totalRecordCount = GetTotalRecordCount(endpoint, dataPartition, kind, query)
    in
        [totalCount = totalRecordCount, results = results, listcount = Table.RowCount(results)];

GetTotalRecordCount = (endpoint as text,
                        dataPartition as text,
                        kind as text, 
                        query as text) as number => 
    let
        startPosition = 0,
        limit = 1,
        runningCount = 0,
        page = GetSearchResultPage(endpoint, dataPartition, kind, query, runningCount, startPosition, limit)
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
                nextPageStartingPosition = if previous = null then 0
                     else Value.Metadata(previous)[startPosition],
                runningCountOfRetrievedRecords = if previous = null then 0
                    else Value.Metadata(previous)[runningCountOfRetrievedRecords],
                table = if RetrievedAllPages(previous, limit) then null // Returning null stops the pagination function
                     else GetSearchResultPage(endpoint, dataPartition, kind, query, runningCountOfRetrievedRecords, nextPageStartingPosition, limit, returnedFields)
            in
                table);

GetSearchResultPage = (endpoint as text,
                        dataPartition as text,
                        kind as text, 
                        query as text,
                        runningCountOfRetrievedRecords as number,
                        startPosition as number, 
                        optional limit as number, 
                        optional returnedFields as text) =>
    let
        adjustedLimit = AdjustPageSizeDependingOnUsersLimit(pageSize, runningCountOfRetrievedRecords, limit),
        body = GetQueryString(kind, query, adjustedLimit, startPosition, returnedFields),
        results = Json.Document(Web.Contents(endpoint,[
            Headers = [#"Content-Type"="application/json", #"data-partition-id"=dataPartition],
            Content = Text.ToBinary(body)
       ])),
       totalNumberOfRecords = results[totalCount],
       nextStart = if List.IsEmpty(results[results]) then 0
             else startPosition + pageSize,
       updatedCount = List.Count(results[results]) + runningCountOfRetrievedRecords,
       resultTable = Table.FromList(results[results], Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    in
       resultTable meta [startPosition = nextStart, totalNumberOfRecords = totalNumberOfRecords, runningCountOfRetrievedRecords = updatedCount];

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
                else if not (limit = null) and collectedItems >= limit then // User specified limit and we retrieved that many records. Using >= comparison in case user specified 0 limit - EDS will default to 10 in that case
                    true
                else // We have more records to retrieve beause we haven't retrieved them all yet, or we haven't reached the user's optional limit
                    false
    in
        didRetrievedAll;

AdjustPageSizeDependingOnUsersLimit = (pageSize as number, runningCountOfRetrievedRecords as number, optional limit as number) as number =>
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

MicrosoftEnergyDataServices = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            clientId = json[clientId],
            tenantId = json[tenantId],
            endpoint = json[endpoint],
            dataPartition = json[dataPartition],
            kind = json[kind],
            query = json[query]
        in
            { "MicrosoftEnergyDataServices.Contents", clientId, tenantId, endpoint, dataPartition, kind, query },
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

MicrosoftEnergyDataServices.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = MicrosoftEnergyDataServices.Icons,
    SourceTypeImage = MicrosoftEnergyDataServices.Icons
];

MicrosoftEnergyDataServices.Icons = [
    Icon16 = { Extension.Contents("MicrosoftEnergyDataServices16.png"), Extension.Contents("MicrosoftEnergyDataServices20.png"), Extension.Contents("MicrosoftEnergyDataServices24.png"), Extension.Contents("MicrosoftEnergyDataServices32.png") },
    Icon32 = { Extension.Contents("MicrosoftEnergyDataServices32.png"), Extension.Contents("MicrosoftEnergyDataServices40.png"), Extension.Contents("MicrosoftEnergyDataServices48.png"), Extension.Contents("MicrosoftEnergyDataServices64.png") }
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
        // ManualHandlingStatusCodes = {400, 403}
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

ValueText.IfNullOrEmpty = (a, b, fieldname) => if (a <> null and a <> "") then  ",""" & fieldname & """: [" & a & "]" else b;
 
GetQueryString = (kind as text, query as text, optional limit as number, optional offset as number, optional returnedFields as text) as text =>
    let
        queryText = "{""kind"": """ & kind & """,""query"": """ & query & """" & ValueNumber.IfNull(limit, "", "limit") & ValueNumber.IfNull(offset, "", "offset") & ValueText.IfNullOrEmpty(returnedFields, "", "returnedFields") & "}"
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