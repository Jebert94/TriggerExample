trigger SalesTrigger on Sales__c (before insert, after update) {

    if(Trigger.isBefore){
        if(Trigger.isInsert){
            SalesHelper.beforeInsert(Trigger.new);
        }
    }else if(Trigger.isAfter){
        if(Trigger.isUpdate){
            SalesHelper.afterUpdate(Trigger.new);
        }
    }
}
