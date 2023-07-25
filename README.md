# SalesTrigger and SalesHelper Classes

## Overview

The `SalesTrigger` and `SalesHelper` classes provide functionalities for the automation of sales and stock updates in the system.

### `SalesTrigger` 

This is a trigger class that gets fired on insert and update events on `Sales__c` objects. If the trigger event is `beforeInsert`, it calls the `beforeInsert` method in the `SalesHelper` class. If the trigger event is `afterUpdate`, it calls the `afterUpdate` method in the `SalesHelper` class.

### `SalesHelper` 

This is a helper class for the `SalesTrigger`. This class provides the logic for processing `Sales__c` objects before they are inserted and after they are updated. This class also includes the `createAndUpdateStockEntries` method for creating and updating stock entries.

## Class Method Descriptions

### `SalesHelper` Methods:

- `beforeInsert(List<Sales__c> incomingSalesList)`: This method processes incoming `Sales__c` records that are being inserted. It checks whether these records meet the criteria for stock entry creation and if non-SKU SKUs can be transformed to SKU SKUs.

- `afterUpdate(List<Sales__c> incomingSalesList)`: This method processes `Sales__c` records after they are updated. It checks whether these records meet the criteria for stock entry creation.

- `createAndUpdateStockEntries(List<PendingStockEntry> pseList, Map<String,Decimal> incomingSalesMap)`: This method creates and updates stock entries using the provided list of pending stock entries and a map of incoming sales.

### `PendingStockEntry` Class:

This nested class within the `SalesHelper` class is used to hold data required to create a new stock entry record. It has the following fields:

- `itemID`: A string that holds the ID of the item.
- `sku`: A string that holds the SKU of the item.
- `quantity`: A decimal value that represents the quantity of the item.

## How to Use

When a new `Sales__c` record is inserted or an existing one is updated, the `SalesTrigger` will automatically call the appropriate methods in the `SalesHelper` class to process the sales and update the stock entries as needed. This will ensure the stock level of the corresponding items are updated appropriately.

## Notes

All Object Names, Methods and Variables have been changed from the original trigger and helper class for security purposes.
