# Microsoft Energy Data Services Power BI Connector

## About

This project is the Microsoft Energy Data Services Power BI connector. The connector is used to query data from a Microsoft Energy Data Services instance and display it in Power BI reports.

## Development Machine Setup

You will need Visual Studio 2019 and the Power Query SDK to compile the project.

1. Install Visual Studio 2019
1. Install the [Power Query SDK](https://marketplace.visualstudio.com/items?itemName=Dakahn.PowerQuerySDK) from the Visual Studio Marketplace

## Testing the Connector
To test the connector you must configure your Microsoft Energy Data Services instance, and connector first.

### Configuring Microsoft Energy Data Services
Add the below URI as a Single Page Application (SPA) redirect URI to your AD Application

    https://oauth.powerbi.com/views/oauthredirect.html

### Configuring the Connector

Provide a client ID, tenant ID, Microsoft Energy Data Services instance name, and data partition ID in [MicrosoftEnergyDataServices.query.pq](./MicrosoftEnergyDataServices/MicrosoftEnergyDataServices/MicrosoftEnergyDataServices.query.pq). Once this is done, you can run the connector by pressing the Run button or F5.

### Using the Sample Report

There is a sample template report that can be used to test your connection. The connection details need to be updated with the following steps:

1. Open [Microsoft Energy Data Services Wells Template.pbit](./Reports/Microsoft%20Energy%20Data%20Services%20Wells%20Template.pbit) 
1. Close the authentication prompt
1. Close the error dialog
1. Edit the 'Wells' query
1. Edit the 'Source' step
1. Input your client ID, tenant ID, Microsoft Energy Data Services instance name, and data parition ID
1. Click 'OK'
1. Click 'Close & Apply'


## Architecture

There are several pieces of the connector that warrant explanation: authentication, paging, and unit tests

### Authentication

OAuth

### Paging

Paging

### Unit Tests

Unit Tests

## Possible Features for the Future

The connector supports basic search functionality, but there are some areas of improvement: 

### Fetch records at a specified index

Data retreival/paging currently starts at index 0, but it could be modified to start at any index. This could be useful if users have a large amount of data and want to fetch a subset of it. This would require modifications to the paging logic to know where to start.

### Support all search API arguments

The Search API has a number of parameters to it: kind, query, offset, limit, sort, queryAsOwner, spatialFilter, trackTotalCount, aggregateBy, and returnedFields. The connector could be extended to support sort, queryAsOwner, spatialFilter, trackTotalCount, and aggregateBy. It currently makes use of kind, query, offset, liimt, and returnedFields.

### Improve returnedRecords format

Passing values to the returnedFields parameter is not the most userfriendly since each field needs to be enclosed in quotes. The connector could be modified to add quotations around each field, if the user doesn't provide them, before passing them to the Search API.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.


## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
