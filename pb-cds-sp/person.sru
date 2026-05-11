$PBExportHeader$person.sru
$PBExportComments$Proxy imported from Web service using Web Service Proxy Generator.
forward
    global type Person from nonvisualobject
    end type
end forward

global type Person from nonvisualobject
end type

type variables
    Address Addr
    datetime DOB
    boolean DOBSpecified
    string DefendantType
    string Eye_Color
    string Hair_Color
    int Height_ft
    boolean Height_ftSpecified
    int Height_in
    boolean Height_inSpecified
    string SSN
    string SSNLast4
    int Weight
    boolean WeightSpecified
    string businessName
    string defendantName
    string firstName
    string fullName
    string generation
    string lastName
    string maidenName
    string middleName
    long opr_lic_cdl_ind
    boolean opr_lic_cdl_indSpecified
    string opr_lic_exp_yr
    long opr_lic_held_flag
    boolean opr_lic_held_flagSpecified
    string opr_lic_number
    string opr_lic_state
    string race
    string sex
end variables

on Person.create
call super::create
TriggerEvent( this, "constructor" )
end on

on Person.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

