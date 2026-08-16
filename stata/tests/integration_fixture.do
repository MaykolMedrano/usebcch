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
    quietly copy "stata/tests/fixtures/getseries_ok.json" `"`destination'"', replace
end

usebcch get F073.TCO.PRE.Z.D, names(dolar) credentials(`"`credentials'"') clear
assert _N==3
assert dolar[1]==877.12
assert time[3]==mdy(1,2,2024)
assert `"`r(layout)'"'=="wide"
assert `"`r(frequency)'"'=="daily"
assert `"`r(source)'"'=="Banco Central de Chile - BDE"
assert `"`r(series_codes)'"'=="F073.TCO.PRE.Z.D"
assert `"`r(names)'"'=="dolar"
assert `"`r(code1)'"'=="F073.TCO.PRE.Z.D"
assert `"`r(name1)'"'=="dolar"
assert `"`r(title_es1)'"'=="Tipo de cambio observado"
assert `"`r(period_start)'"'=="29dec2023"
assert `"`r(period_end)'"'=="02jan2024"
local daily_format : format time
assert `"`daily_format'"'=="%td"
local dolar_label : variable label dolar
assert `"`dolar_label'"'=="Tipo de cambio observado"
local dolar_code : char dolar[usebcch_series]
assert `"`dolar_code'"'=="F073.TCO.PRE.Z.D"
local dataset_source : char _dta[usebcch_source]
assert `"`dataset_source'"'=="Banco Central de Chile - BDE"

usebcch get F073.TCO.PRE.Z.D, long credentials(`"`credentials'"') clear
assert _N==3
assert status[2]=="ND"
assert missing(value[2])
assert value_raw[2]=="NaN"
assert `"`r(layout)'"'=="long"
assert `"`r(frequency)'"'=="daily"
assert `"`r(title_es1)'"'=="Tipo de cambio observado"

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy "stata/tests/fixtures/getseries_title_hierarchy.json" `"`destination'"', replace
end

usebcch get F073.TCO.PRE.Z.D, names(dolar) credentials(`"`credentials'"') clear
local hierarchy_label : variable label dolar
assert `"`hierarchy_label'"'=="Tipo de cambio nominal (dólar observado /USD)"
local hierarchy_full : char dolar[usebcch_title_es]
assert `"`hierarchy_full'"'=="Tipo de cambio nominal (dólar observado /USD)\ tipo de cambio \ precio \ diario \ BCCh"

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy "stata/tests/fixtures/searchseries_ok.json" `"`destination'"', replace
end

usebcch search "tipo", frequency(daily) language(es) ///
    credentials(`"`credentials'"') clear
assert _N==1
assert series_id[1]=="F073.TCO.PRE.Z.D"
assert first_observation[1]==mdy(1,2,1984)

usebcch search "tipo de cambio", frequency(daily) language(es) ///
    credentials(`"`credentials'"') clear
assert _N==1
assert series_id[1]=="F073.TCO.PRE.Z.D"

display as result "usebcch fixture integration: all tests passed"
