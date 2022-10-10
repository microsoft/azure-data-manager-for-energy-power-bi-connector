// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

[Version="1.0.0"]
section MicrosoftEnergyDataServicesTests;

// Tests must be run against an instance that's completed a TNO data load: https://github.com/Azure/osdu-data-load-tno
clientId = "<client id>";
tenantId = "<tenant id>";
instanceName = "<Microsoft Energy Data Services instance name>";
datapatition = "<data patition ID>";
kind = "osdu:wks:master-data--Well:1.0.0";
query = "*";

shared MicrosoftEnergyDataServices.Test = 
[
    // Fact(<Name of the Test>, <Expected Value>, <Actual Value>)
    facts = 
    {
        Fact("Check that total record count is calculated when there is no limit",
            4947,
            GetTotalCount(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query))),
        Fact("Check that total record count is calculated there is a limit",
            4947,
            GetTotalCount(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         204))),
        Fact("Check that correct number of records are retrieved when there is no limit",
            4947,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query))),
        Fact("Check that correct number of records are retrieved when there is a query",
            4947,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         "type:master-data--Well"))),
       Fact("Check that correct number of records are retrieved when there is a query and a limit",
            2,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         "type:master-data--Well",
                                         2))),
        Fact("Check that correct number of records are retrieved when the limit is greater than the service's max page size",
            1500,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         1500))),
        Fact("Check that correct number of records are retrieved when the limit equals the service's max page size",
            1000,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         1000))),
        Fact("Check that correct number of records are retrieved when the limit is equal to the connectors's page size",
            100,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         100))),
        Fact("Check that correct number of records are retrieved when the limit is less than the connectors's page size",
            10,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         10))),
        Fact("Check that correct number of records are retrieved when the limit is equal to the total count",
            4947,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         4947))),
        Fact("Check that correct number of records are retrieved when the limit is greater than the total count",
            4947,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         5000))),
        Fact("Check that correct number of records are retrieved when the limit is 0",
            10, // Microsoft Energy Data Services will default to 10 if the limit is 0
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         0))),
        Fact("Check that a partial final page, where the difference in limit and page size is greater than the page size, retrieves the correct number of records",
            204,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         204))),
        Fact("Check that a partial final page, where the difference in limit and page size is less than the page size, retrieves the correct number of records",
            150,
            GetNumberOfRows(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         150))),
        Fact("Check that all paged records are unique",
            true,
            List.IsDistinct(GetRecordIds(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query)))),
        Fact("Check that all paged records are unique when there is a limit",
            true,
            List.IsDistinct(GetRecordIds(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         150)))),
        Fact("Check that the number of returnedFields is correct",
            1,
            GetNumberOfRecordProperties(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         10,
                                         """id"""))),
        Fact("Check that the record's fields are projected to returnedFields",
            true,
            FirstRecordHasField(MicrosoftEnergyDataServices.Search(clientId,
                                         tenantId,
                                         instanceName,
                                         datapatition,
                                         kind,
                                         query,
                                         10,
                                         """id"""),
                                "id"))
    },
    report = Facts.Summarize(facts)
][report];

GetTotalCount = (result as table) => 
   result{[Key=kind]}[Data]{[Name="Count"]}[Value];

GetNumberOfRows = (result as table) => 
    Table.RowCount(result{[Key=kind]}[Data]{[Name="Records"]}[Value]);

GetRecordIds = (result as table) => 
    let
        records = result{[Key=kind]}[Data]{[Name="Records"]}[Value]
    in
        Table.ExpandRecordColumn(records, "Records", {"id"}, {"id"})[id];

GetNumberOfRecordProperties = (result as table) => 
    let
        records = result{[Key="osdu:wks:master-data--Well:1.0.0"]}[Data]{[Name="Records"]}[Value],
        recordProperties = Record.ToList(records{0}[Records])
    in
        List.Count(recordProperties);

FirstRecordHasField = (result as table, field as text) => 
    let
        records = result{[Key="osdu:wks:master-data--Well:1.0.0"]}[Data]{[Name="Records"]}[Value]
    in
        Record.HasFields(records{0}[Records], field);

/// COMMON UNIT TESTING CODE 
Fact = (_subject as text, _expected, _actual) as record =>
[   expected = try _expected,
    safeExpected = if expected[HasError] then "Expected : "& @ValueToText(expected[Error]) else expected[Value],
    actual = try _actual,
    safeActual = if actual[HasError] then "Actual : "& @ValueToText(actual[Error]) else actual[Value],
    attempt = try safeExpected = safeActual,
    result = if attempt[HasError] or not attempt[Value] then "Failure ⛔" else "Success ✓",
    resultOp = if result = "Success ✓" then " = " else " <> ",
    addendumEvalAttempt = if attempt[HasError] then @ValueToText(attempt[Error]) else "",
    addendumEvalExpected = try @ValueToText(safeExpected) otherwise "...",
    addendumEvalActual = try @ValueToText (safeActual) otherwise "...",
    fact =
    [   Result = result &" "& addendumEvalAttempt,
        Notes =_subject,
        Details = " ("& addendumEvalExpected & resultOp & addendumEvalActual &")"
    ]
][fact];

Facts = (_subject as text, _predicates as list) => List.Transform(_predicates, each Fact(_subject,_{0},_{1}));

Facts.Summarize = (_facts as list) as table =>
[   Fact.CountSuccesses = (count, i) =>
    [   result = try i[Result],
        sum = if result[HasError] or not Text.StartsWith(result[Value], "Success") then count else count + 1
    ][sum],
    passed = List.Accumulate(_facts, 0, Fact.CountSuccesses),
    total = List.Count(_facts),
    format = if passed = total then "All #{0} Passed !!! ✓" else "#{0} Passed ☺  #{1} Failed ☹",
    result = if passed = total then "Success" else "⛔",
    rate = Number.IntegerDivide(100*passed, total),
    header =
    [   Result = result,
        Notes = Text.Format(format, {passed, total-passed}),
        Details = Text.Format("#{0}% success rate", {rate})
    ],
    report = Table.FromRecords(List.Combine({{header},_facts}))
][report];

ValueToText = (value, optional depth) =>
    let
        List.TransformAndCombine = (list, transform, separator) => Text.Combine(List.Transform(list, transform), separator),

        Serialize.Binary =      (x) => "#binary(" & Serialize(Binary.ToList(x)) & ") ",

        Serialize.Function =    (x) => _serialize_function_param_type(
                                          Type.FunctionParameters(Value.Type(x)),
                                          Type.FunctionRequiredParameters(Value.Type(x)) ) &
                                       " as " &
                                       _serialize_function_return_type(Value.Type(x)) &
                                       " => (...) ",

        Serialize.List =        (x) => "{" & List.TransformAndCombine(x, Serialize, ", ") & "} ",

        Serialize.Record =      (x) => "[ " &
                                       List.TransformAndCombine(
                                            Record.FieldNames(x), 
                                            (item) => Serialize.Identifier(item) & " = " & Serialize(Record.Field(x, item)),
                                            ", ") &
                                       " ] ",

        Serialize.Table =       (x) => "#table( type " &
                                        _serialize_table_type(Value.Type(x)) &
                                        ", " &
                                        Serialize(Table.ToRows(x)) &
                                        ") ",
                                    
        Serialize.Identifier =  Expression.Identifier,

        Serialize.Type =        (x) => "type " & _serialize_typename(x),
                                    
                             
        _serialize_typename =    (x, optional funtype as logical) =>                        /* Optional parameter: Is this being used as part of a function signature? */
                                    let
                                        isFunctionType = (x as type) => try if Type.FunctionReturn(x) is type then true else false otherwise false,
                                        isTableType = (x as type) =>  try if Type.TableSchema(x) is table then true else false otherwise false,
                                        isRecordType = (x as type) => try if Type.ClosedRecord(x) is type then true else false otherwise false,
                                        isListType = (x as type) => try if Type.ListItem(x) is type then true else false otherwise false
                                    in
                                
                                        if funtype=null and isTableType(x) then _serialize_table_type(x) else
                                        if funtype=null and isListType(x) then "{ " & @_serialize_typename( Type.ListItem(x) ) & " }" else
                                        if funtype=null and isFunctionType(x) then "function " & _serialize_function_type(x) else
                                        if funtype=null and isRecordType(x) then _serialize_record_type(x) else
                                    
                                        if x = type any then "any" else
                                        let base = Type.NonNullable(x) in
                                          (if Type.IsNullable(x) then "nullable " else "") &       
                                          (if base = type anynonnull then "anynonnull" else                
                                          if base = type binary then "binary" else                
                                          if base = type date   then "date"   else
                                          if base = type datetime then "datetime" else
                                          if base = type datetimezone then "datetimezone" else
                                          if base = type duration then "duration" else
                                          if base = type logical then "logical" else
                                          if base = type none then "none" else
                                          if base = type null then "null" else
                                          if base = type number then "number" else
                                          if base = type text then "text" else 
                                          if base = type time then "time" else 
                                          if base = type type then "type" else 
                                      
                                          /* Abstract types: */
                                          if base = type function then "function" else
                                          if base = type table then "table" else
                                          if base = type record then "record" else
                                          if base = type list then "list" else
                                      
                                          "any /*Actually unknown type*/"),

        _serialize_table_type =     (x) => 
                                           let 
                                             schema = Type.TableSchema(x)
                                           in
                                             "table " &
                                             (if Table.IsEmpty(schema) then "" else 
                                                 "[" & List.TransformAndCombine(
                                                     Table.ToRecords(Table.Sort(schema,"Position")),
                                                     each Serialize.Identifier(_[Name]) & " = " & _[Kind],
                                                     ", ") &
                                                 "] "),

        _serialize_record_type =    (x) => 
                                            let flds = Type.RecordFields(x)
                                            in
                                                if Record.FieldCount(flds)=0 then "record" else
                                                    "[" & List.TransformAndCombine(
                                                        Record.FieldNames(flds),
                                                        (item) => Serialize.Identifier(item) & "=" & _serialize_typename(Record.Field(flds,item)[Type]),
                                                        ", ") & 
                                                    (if Type.IsOpenRecord(x) then ", ..." else "") &
                                                    "]",

        _serialize_function_type =  (x) => _serialize_function_param_type(
                                              Type.FunctionParameters(x),
                                              Type.FunctionRequiredParameters(x) ) &
                                            " as " &
                                            _serialize_function_return_type(x),
    
        _serialize_function_param_type = (t,n) => 
                                let
                                    funsig = Table.ToRecords(
                                        Table.TransformColumns(
                                            Table.AddIndexColumn( Record.ToTable( t ), "isOptional", 1 ),
                                            { "isOptional", (x)=> x>n } ) )
                                in
                                    "(" & 
                                    List.TransformAndCombine(
                                        funsig,
                                        (item)=>
                                            (if item[isOptional] then "optional " else "") &
                                            Serialize.Identifier(item[Name]) & " as " & _serialize_typename(item[Value], true),
                                        ", ") &
                                     ")",

        _serialize_function_return_type = (x) => _serialize_typename(Type.FunctionReturn(x), true), 

        Serialize = (x) as text => 
                           if x is binary       then try Serialize.Binary(x) otherwise "null /*serialize failed*/"        else 
                           if x is date         then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is datetime     then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is datetimezone then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is duration     then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is function     then try Serialize.Function(x) otherwise "null /*serialize failed*/"      else 
                           if x is list         then try Serialize.List(x) otherwise "null /*serialize failed*/"          else 
                           if x is logical      then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else
                           if x is null         then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else
                           if x is number       then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else
                           if x is record       then try Serialize.Record(x) otherwise "null /*serialize failed*/"        else 
                           if x is table        then try Serialize.Table(x) otherwise "null /*serialize failed*/"         else 
                           if x is text         then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is time         then try Expression.Constant(x) otherwise "null /*serialize failed*/"     else 
                           if x is type         then try Serialize.Type(x) otherwise "null /*serialize failed*/"          else 
                           "[#_unable_to_serialize_#]"                     
    in
        try Serialize(value) otherwise "<serialization failed>";