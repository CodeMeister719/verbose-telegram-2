$PBExportHeader$paymenttender.sru
$PBExportComments$Proxy imported from Web service using Web Service Proxy Generator.
forward
    global type PaymentTender from nonvisualobject
    end type
end forward

global type PaymentTender from nonvisualobject
end type

type variables
    decimal amount
    boolean amountSpecified
    string associatedNumber
    string checkIDNumber
    string checkIDType
    string paymentReferenceNumber
    string tenderType
end variables

on PaymentTender.create
call super::create
TriggerEvent( this, "constructor" )
end on

on PaymentTender.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

