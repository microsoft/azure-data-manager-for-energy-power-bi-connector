// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
let
    result = MicrosoftEnergyDataServices.Contents("f5e3329f-3963-4484-83e5-2acbf00cdad3",
                                         "72f988bf-86f1-41af-91ab-2d7cd011db47",
                                         "https://platform4832.energy.azure.com/api/search/v2/query",
                                         "platform4832-opendes",
                                         "osdu:wks:master-data--Well:1.0.0",
                                         "*",
                                         400)
in
    result