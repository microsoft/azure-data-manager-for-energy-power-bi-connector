// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
let
    result = MicrosoftEnergyDataServices.Contents("<Client ID>",
                                         "<Tenant ID>",
                                         "https://<MEDS Name>.energy.azure.com/api/search/v2/query",
                                         "<Data Patition Name>",
                                         "osdu:wks:master-data--Well:1.0.0",
                                         "*")
in
    result