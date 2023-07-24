public with sharing class SalesHelper {
    public SalesHelper() {
    }

    // Defined nested class used to hold data required to create a new Stock Entry record
    private class PendingStockEntry{
        private string itemID;
        private String sku;
        private Decimal quantity;
    }

    // Function used to process incoming Sales records that are being inserted
    public static void beforeInsert(List <Sales__c> incomingSalesList){
        // Instantiate a List used to temporarally hold data for new Stock Entries 
        List<PendingStockEntry> pseList = new List<PendingStockEntry>();
        
        // Instantiate a Map that will be used to add up the quantities from the incoming Sales records and relate them to the item sku
        // (Key = Item's SKU, Value = Sum of the Quantity of all Sales records for that SKU)
        Map<String,Decimal> incomingSalesMap = new Map<String,Decimal>();


        // Instantiate and Populate a Map used to clean up incoming Sales records with non SKU skus 
        // (Key = Item's External ID, Value = Item's SKU)
        Map<String,String> nonSKUItemsMap = new Map<String,String>();

        List<Item__c> nonSKUItemsList = [SELECT id, sku__c, external_ID__C
                                                    FROM Item__c 
                                                    WHERE sku__c LIKE 'SKU%' AND (NOT External_ID__c LIKE 'SKU%') AND External_ID__c != NULL
                                                ];
                                       
        for(Item__c item : nonSKUItemsList){
            nonSKUItemsMap.put(item.external_ID__c, item.sku__c);
        }
        
        //Checks if Sales records meet the criteria for stock entry creation and if non-SKU SKUs can be transformed to SKU SKUs
        for(Sales__c s : incomingSalesList){
            if(s.is_deducted__c == false){
                if(String.isNotBlank(s.sku__c)){            
                    if(s.sku__c.contains('SKU')){
                        if(s.tracking_number__c != null){   // move tracking number behind sku   
                            if(!s.Fulfillment_Type__c.contains('wholesale')){
                                if(!incomingSalesMap.containsKey(s.sku__c)){
                                    PendingStockEntry pse = new PendingStockEntry();
                                        pse.sku = s.sku__c;
                                    pseList.add(pse);
                                    incomingSalesMap.put(s.sku__c, s.QTY__c);
                                    s.is_deducted__c = true;
                                }else{
                                    incomingSalesMap.put(s.sku__c, incomingSalesMap.get(s.sku__c) + s.QTY__c);
                                    s.is_deducted__c = true;
                                }
                            }
                        }
                    }
                }
            }
        }
        if(pseList.size()>0){
        	createAndUpdateStockEntries(pseList, incomingSalesMap);
      	}
    }
       


    public static void afterUpdate(List <Sales__c> incomingSalesList){

        // Instantiate a List used to  hold updated Sales records 
        List<Sales__c> updatedSalesList = new List<Sales__c>();

        // Instantiate a List used to temporarally hold data for new Stock Entries 
        List<PendingStockEntry> pseList = new List<PendingStockEntry>();

        // Instantiate a Map that will be used to add up the quantities from the incoming Sales records and relate them to the item sku
        // (Key = Item's SKU, Value = Sum of the Quantity of all Sales records for that SKU)
        Map<String,Decimal> incomingSalesMap = new Map<String,Decimal>();

        for(Sales__c s : incomingSalesList){
            if(s.is_deducted__c == false){
                if(s.tracking_number__c != null){
                    if(String.isNotBlank(s.sku__c)){  
                        if(s.sku__c.contains('SKU')){
                            if(!s.Fulfillment_Type__c.contains('wholesale')){
                                if(!incomingSalesMap.containsKey(s.sku__c)){
                                    PendingStockEntry pse = new PendingStockEntry();
                                            pse.sku = s.sku__c;
                                        pseList.add(pse);
                                        incomingSalesMap.put(s.sku__c, s.QTY__c);    
                                    Sales__c newSales = new Sales__c(id=s.id);
                                        newSales.is_deducted__c = true;
                                        updatedSalesList.add(newSales);
                                }else{
                                    incomingSalesMap.put(s.sku__c, incomingSalesMap.get(s.sku__c) + s.QTY__c);
                                    Sales__c newSales = new Sales__c(id=s.id);
                                        newSales.is_deducted__c = true;
                                        updatedSalesList.add(newSales);
                                }  
                            }
                        }
                    }
                }

            }
        }
         if(pseList.size()>0){
            update updatedSalesList;
            createAndUpdateStockEntries(pseList, incomingSalesMap);
         }
    }





    //Function to Create and Update stock entry records, requires SalesMAP + pseList
    private static void createAndUpdateStockEntries(List<PendingStockEntry> pseList, Map<String,Decimal> incomingSalesMap ){

        //Set used to gather all the unique skus to be used for querying the items
        Set<String> uniqueSalesSKUSet = incomingSalesMap.keySet();
        
        List<Item__c> itemList = [SELECT id, sku__c
                                                FROM Item__c
                                                WHERE sku__c = :uniqueSalesSKUSet
                                            ];        
        
        //List used to store item Ids for SE querying
        List<String> itemIDList = new List<String>();
        
        // Combining and storing the information for each sku to create a new SE record 
        for(PendingStockEntry pse : pseList){
            for(Item__c item : itemList){
                if(pse.sku == item.sku__c ){
                    pse.quantity = incomingSalesMap.get(pse.sku);
                    pse.itemID = item.Id;
                    itemIDList.add(item.id);
                }
            }
        }
        
        // query the old SE records that need to be adjusted
        List<Stock_Entry__c> oldSEList = [SELECT Item__c, Unis_in_Stock__c, Last_Record__c
                                            FROM Stock_Entry__c
                                            WHERE Last_Record__c = true AND Pallet_Location__c = '1234'  AND Item__c = :itemIDList
                                        ];
        
        //Liss used to store created/modified data
        List <Stock_Entry__c> oldSEToUpdateList = new List <Stock_Entry__c>();
        List <Stock_Entry__c> newSEToInsertList = new List <Stock_Entry__c>();

        //Create a new SE with the adjusted quantity and set the old SE Lastrecord field as false
        try{
            for(Stock_Entry__c oldSE : oldSEList){
                for(PendingStockEntry pse : pseList){
                    if(oldSE.Item__c == pse.itemID){
                        Stock_Entry__c newSE = new Stock_Entry__c();
                            newSE.Item__c = pse.itemID;
                            newSE.Unis_Entry__c = pse.quantity;
                            newSE.Unis_in_Stock__c = oldSE.Unis_in_Stock__c - pse.quantity;
                            newSE.Last_Record__c = true;
                            newSE.Effective_Start_Date__c = system.today(); //current datetime
                            newSE.Warehouse_name__c = 'First Warehouse' ;
                            newSE.Aisle__c = '1' ;
                            newSE.Section__c = 2 ;
                            newSE.Shelf__c = '34' ;
                            newSE.Account_Item_Owner__c = '123456789A' ;
                            newSE.Status__c = 'New' ;
                            newSE.Automated_Stock__c = true;
                            newSE.Pallet_Location__c = '1234';
                            newSE.P_O__c = 'AutoPull-'+ date.today().format();
                        newSEToInsertList.add(newSE);
                        
                        oldSE.Last_Record__c = false;
                        oldSE.Effective_End_Date__c = system.today();
                        oldSEToUpdateList.add(oldSE);
                    }
                }
            }
            //import the data
            update oldSEToUpdateList;
            insert newSEToInsertList;

        }catch(DMLException e)
        {
            Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {'TechTeam@someemail.com'};
            mail.setToAddresses(toAddresses);
            mail.setReplyTo('TechTeam@someemail.com');
            mail.setSenderDisplayName('Apex error message');
            mail.setSubject('Error from Org : ' + UserInfo.getOrganizationName() + '  Apex Trigger: Sales Stock Entry Creation');
            String body = 'New Stock entries attempting to be created but failed \n\n';
            mail.setPlainTextBody( body + e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}
