version 16.0
clear all
adopath ++ "stata"
do stata/usebcch.ado

tempfile personalmarker credentials
local personaldir `"`personalmarker'_dir"'
mkdir `"`personaldir'"'
sysdir set PERSONAL `"`personaldir'"'

tempname handle
file open `handle' using `"`credentials'"', write text
file write `handle' "fixture-user" _n "fixture-password" _n
file close `handle'

usebcch cache clear

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    quietly copy "stata/tests/fixtures/searchseries_ok.json" `"`destination'"', replace
end

usebcch search "tipo", frequency(daily) cache ///
    credentials(`"`credentials'"') clear
assert _N==1
assert r(cache_hits)==0
assert r(downloads)==1

program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    display as error "network should not be called on a cache hit"
    exit 999
end

usebcch search "tipo", frequency(daily) cache clear
assert _N==1
assert r(cache_hits)==1
assert r(downloads)==0

usebcch cache status
assert r(N)==1
assert `"`r(frequencies)'"'=="daily"
usebcch cache clear
usebcch cache status
assert r(N)==0

display as result "usebcch cache tests passed"
