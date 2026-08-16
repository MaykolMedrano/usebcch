version 16.0
clear all
adopath ++ "stata"
do stata/usebcch.ado

tempfile credentials
tempname handle
file open `handle' using `"`credentials'"', write text
file write `handle' "fixture-user" _n "fixture-password" _n
file close `handle'

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy "stata/tests/fixtures/getseries_empty.json" `"`destination'"', replace
end

usebcch get F073.TCO.PRE.Z.D, names(emptyseries) ///
    credentials(`"`credentials'"') clear
assert _N==0
confirm numeric variable time
confirm numeric variable emptyseries

program drop _usebcch_copy
global USEBCCH_MOCK_COUNT 0
program define _usebcch_copy
    version 16.0
    args url destination
    global USEBCCH_MOCK_COUNT=$USEBCCH_MOCK_COUNT+1
    if $USEBCCH_MOCK_COUNT==1 {
        quietly copy "stata/tests/fixtures/getseries_empty.json" `"`destination'"', replace
    }
    else {
        quietly copy "stata/tests/fixtures/getseries_second_ok.json" `"`destination'"', replace
    }
end

usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(first second) credentials(`"`credentials'"') clear
assert _N==2
assert missing(first)
assert second==8.25
macro drop USEBCCH_MOCK_COUNT

display as result "usebcch empty/mixed schema tests passed"
