version 16.0
clear all
adopath ++ "stata"
do stata/usebcch.ado

usebcch get F073.TCO.PRE.Z.D, from(2024-01-02) to(2024-01-10) long clear
assert _N>0
assert series_id=="F073.TCO.PRE.Z.D"
assert inrange(time,mdy(1,2,2024),mdy(1,10,2024))
assert !missing(value) if status=="OK"

usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(dolar tpm) from(2024-01-02) to(2024-01-10) clear
assert _N>0
assert `"`r(title_es1)'"'!=""
assert `"`r(title_es2)'"'!=""
assert `"`r(series_codes)'"'=="F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D"
confirm numeric variable dolar
confirm numeric variable tpm
local dolar_label : variable label dolar
local tpm_label : variable label tpm
assert `"`dolar_label'"'!="" & `"`tpm_label'"'!=""
count if !missing(dolar) | !missing(tpm)
assert r(N)>0

usebcch search "IPC", frequency(monthly) language(es) clear
assert _N>0
assert frequency=="MONTHLY"
assert ustrpos(ustrlower(spanish_title),"ipc")>0

display as result "usebcch live success tests passed"
