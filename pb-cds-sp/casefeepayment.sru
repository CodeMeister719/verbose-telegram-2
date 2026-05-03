$PBExportHeader$casefeepayment.sru
$PBExportComments$Proxy imported from Web service using Web Service Proxy Generator.
forward
    global type CaseFeePayment from nonvisualobject
    end type
end forward

global type CaseFeePayment from nonvisualobject
end type

type variables
    decimal Amount
    boolean AmountSpecified
    decimal AmountPerFeeCode
    boolean AmountPerFeeCodeSpecified
    long ChargeSequenceNumber
    boolean ChargeSequenceNumberSpecified
    string FeeCode
    long FeeCodeSequenceNumber
    boolean FeeCodeSequenceNumberSpecified
    long LkbxBatchTranNumber
    boolean LkbxBatchTranNumberSpecified
    long LkbxPaymentBatchNumber
    boolean LkbxPaymentBatchNumberSpecified
    string NextDocketCourtRoom
    datetime NextDocketDateTime
    boolean NextDocketDateTimeSpecified
    string caseFeeCategory
    string caseNumber
end variables

on CaseFeePayment.create
call super::create
TriggerEvent( this, "constructor" )
end on

on CaseFeePayment.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

