version 16.0
clear all
set more off

/* Exercise the installed package, not the source files in the current folder. */
local repo_root = subinstr(c(pwd), "\", "/", .)
local package_root `"`repo_root'/stata"'
tempname installation_id
local run_date = subinstr(c(current_date), " ", "", .)
local run_time = subinstr(c(current_time), ":", "", .)
local personal_dir `"`c(tmpdir)'/usebcch-package-`run_date'-`run_time'-`installation_id'"'
capture mkdir `"`personal_dir'"'
sysdir set PERSONAL `"`personal_dir'"'
net set ado PERSONAL
cd `"`personal_dir'"'

net install usebcch, from(`"`package_root'"') replace
findfile usebcch.ado
local installed_ado = subinstr(`"`r(fn)'"', "\", "/", .)
if substr(`"`installed_ado'"', 1, 1)=="." {
    local current_dir = subinstr(c(pwd), "\", "/", .)
    local installed_ado `"`current_dir'/`installed_ado'"'
}
local installed_ado : subinstr local installed_ado "/./" "/", all
local expected_dir = subinstr(`"`personal_dir'"', "\", "/", .)
local expected_dir : subinstr local expected_dir "//" "/", all
if strpos(lower(`"`installed_ado'"'), lower(`"`expected_dir'"')) != 1 {
    display as error "usebcch.ado was not loaded from the temporary PERSONAL directory"
    exit 9
}
which usebcch
findfile usebcch.sthlp
help usebcch

capture noisily usebcch unknown
assert _rc==198

sysuse auto, clear
local original_N=_N
capture noisily usebcch get F073.TCO.PRE.Z.D
assert _rc==4
assert _N==`original_N'

capture noisily usebcch get F073.TCO.PRE.Z.D, from(2024-99-01) clear
assert _rc==198
assert _N==`original_N'

capture noisily usebcch search IPC, frequency(weekly) clear
assert _rc==198
assert _N==`original_N'

tempfile credentials
tempname credentials_handle
file open `credentials_handle' using `"`credentials'"', write text
file write `credentials_handle' "fixture-user" _n "fixture-password" _n
file close `credentials_handle'

tempfile envcredentials
tempname env_handle
file open `env_handle' using `"`envcredentials'"', write text
file write `env_handle' "BCCH_USER=fixture-user" _n ///
    "BCCH_PASSWORD='fixture-password'" _n
file close `env_handle'

capture noisily usebcch get F073.TCO.PRE.Z.D, ///
    credentials(`"`credentials'"') envfile(`"`envcredentials'"') clear
assert _rc==198
assert _N==`original_N'

/* Load installed subprograms persistently so the transport can be stubbed. */
capture program drop usebcch
quietly do `"`installed_ado'"'
global UBCCH_TEST_ROOT `"`repo_root'"'
capture program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy `"$UBCCH_TEST_ROOT/stata/tests/fixtures/getseries_ok.json"' ///
        `"`destination'"', replace
end

usebcch auth set, envfile(`"`envcredentials'"')
assert r(configured)==1 & r(valid)==1
usebcch get F073.TCO.PRE.Z.D, names(dolar) clear
assert r(N)==3
assert `"`r(layout)'"'=="wide"
assert `"`r(title_es1)'"'=="Tipo de cambio observado"
assert _N==3
assert dolar[1]==877.12
local installed_label : variable label dolar
assert `"`installed_label'"'=="Tipo de cambio observado"
local installed_code : char dolar[usebcch_series]
assert `"`installed_code'"'=="F073.TCO.PRE.Z.D"

usebcch get F073.TCO.PRE.Z.D, long envfile(`"`envcredentials'"') clear
assert r(N)==3
assert `"`r(layout)'"'=="long"
assert status[2]=="ND"

capture program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy `"$UBCCH_TEST_ROOT/stata/tests/fixtures/searchseries_ok.json"' ///
        `"`destination'"', replace
end

usebcch search "tipo", frequency(daily) language(es) ///
    credentials(`"`credentials'"') clear
assert r(N)==1
assert series_id[1]=="F073.TCO.PRE.Z.D"

usebcch auth clear
assert r(configured)==0

macro drop UBCCH_TEST_ROOT
display as result "usebcch package installation/interface tests passed"
