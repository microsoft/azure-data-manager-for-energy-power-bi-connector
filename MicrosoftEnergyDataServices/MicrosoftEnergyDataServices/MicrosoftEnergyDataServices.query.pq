// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
let
    result = MicrosoftEnergyDataServices.Contents("f5e3329f-3963-4484-83e5-2acbf00cdad3",
                                         "72f988bf-86f1-41af-91ab-2d7cd011db47",
                                         "https://platform4832.energy.azure.com/api/search/v2/query",
                                         "platform4832-opendes",
                                         "osdu:wks:reference-data--*:1.0.0",
                                         "*",
                                         0) 
                                         // Cases
                                         //// Limit > 1000
                                         //// Limit = 1000
                                         //// Limit < 1000
                                         //// No limit
                                         //// Limit > page size
                                         //// Limit = page size
                                         //// Limit < page size
                                         //// Limit = 0 (broken) - oak defaults to 10 and then connector logic falls apart
                                         //// Limit < 0
                                         //// Limit > page size && limit < 1000
                                         //// Limit = max record count && limit < 1000
                                         //// Limit 1 less than max record count (broken)
                                            //// Not working osdu:wks:master-data--Organisation:1.0.0 (max 213) limit 212

                                         //// Max count < 100 (page size)
                                         //// Max count = 100
                                         //// Max count > 100
in
    result