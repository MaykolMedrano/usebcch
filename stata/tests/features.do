version 16.0
clear all
adopath ++ "."
do stata/usebcch.ado

tempfile credentials
tempname handle
file open `handle' using `"`credentials'"', write text
file write `handle' "fixture-user" _n "fixture-password" _n
file close `handle'

program drop _usebcch_copy
global USEBCCH_MOCK_COUNT 0
program define _usebcch_copy
    version 16.0
    args url destination
    global USEBCCH_MOCK_COUNT=$USEBCCH_MOCK_COUNT+1
    if $USEBCCH_MOCK_COUNT==1 {
        quietly copy "stata/tests/fixtures/getseries_transform_a.json" `"`destination'"', replace
    }
    else {
        quietly copy "stata/tests/fixtures/getseries_transform_b.json" `"`destination'"', replace
    }
end

usebcch get TEST.A.D TEST.B.D, names(a b) frequency(monthly) ///
    aggregate(mean last) variation(1) credentials(`"`credentials'"') clear
assert _N==3
assert time[1]==ym(2024,1)
assert time[2]==ym(2024,2)
assert time[3]==ym(2024,3)
local time_format : format time
assert `"`time_format'"'=="%tm"
local returned_frequency `"`r(frequency)'"'
local returned_variation=r(variation)
tsset time
assert missing(a[1]) & missing(b[1])
assert reldif(a[2],40/15-1)<1e-10
assert reldif(a[3],60/40-1)<1e-10
assert reldif(b[2],400/200-1)<1e-10
assert reldif(b[3],800/400-1)<1e-10
assert `"`returned_frequency'"'=="monthly"
assert `returned_variation'==1

program drop _usebcch_copy
global USEBCCH_MOCK_COUNT 0
program define _usebcch_copy
    version 16.0
    args url destination
    global USEBCCH_MOCK_COUNT=$USEBCCH_MOCK_COUNT+1
    if $USEBCCH_MOCK_COUNT==1 {
        quietly copy "stata/tests/fixtures/error_invalid_series.json" `"`destination'"', replace
    }
    else {
        quietly copy "stata/tests/fixtures/getseries_second_ok.json" `"`destination'"', replace
    }
end

usebcch get BAD.SERIES F022.TPM.TIN.D001.NO.Z.D, names(bad tpm) ///
    skipinvalid credentials(`"`credentials'"') clear
assert _N==2
confirm variable tpm
capture confirm variable bad
assert _rc==111
assert r(successful_series)==1
assert `"`r(failed_series)'"'=="BAD.SERIES"

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy "stata/tests/fixtures/searchseries_ok.json" `"`destination'"', replace
end

usebcch search "^tipo.*observado$", frequency(daily) language(es) regex ///
    credentials(`"`credentials'"') clear
assert _N==1
assert series_id=="F073.TCO.PRE.Z.D"

macro drop USEBCCH_MOCK_COUNT
display as result "usebcch advanced feature tests passed"
