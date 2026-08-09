version 16.0
clear all
adopath ++ "."
do stata/usebcch.ado

usebcch get F073.TCO.PRE.Z.D F022.TPM.TIN.D001.NO.Z.D, ///
    names(dolar tpm) from(2023-01-01) to(2024-03-31) ///
    frequency(monthly) aggregate(mean last) variation(12) clear
assert _N==15
assert time[1]==ym(2023,1)
assert time[_N]==ym(2024,3)
local time_format : format time
assert `"`time_format'"'=="%tm"
tsset time
count if !missing(dolar) | !missing(tpm)
assert r(N)>0

usebcch get THIS.SERIES.DOES.NOT.EXIST F073.TCO.PRE.Z.D, ///
    names(bad dolar) from(2024-01-02) to(2024-01-05) skipinvalid clear
assert _N>0
confirm numeric variable dolar
capture confirm variable bad
assert _rc==111
assert r(successful_series)==1
assert `"`r(failed_series)'"'=="THIS.SERIES.DOES.NOT.EXIST"

tempfile personalmarker
local personaldir `"`personalmarker'_dir"'
mkdir `"`personaldir'"'
sysdir set PERSONAL `"`personaldir'"'
usebcch search "^ipc", frequency(monthly) language(es) regex cache refresh clear
assert _N>0
assert r(downloads)==1 & r(cache_hits)==0
usebcch search "^ipc", frequency(monthly) language(es) regex cache clear
assert _N>0
assert r(downloads)==0 & r(cache_hits)==1
usebcch cache clear

display as result "usebcch live advanced tests passed"
