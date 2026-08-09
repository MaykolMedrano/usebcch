version 16.0
clear all
set more off

/*
    Compatibility smoke test.

    This runs on the available Stata binary under Stata 16 version control and
    deliberately loads usebcch from a clean net install.  Network responses are
    replaced with checked-in fixtures, so the test needs no BCCh credentials.
*/
local project `"`c(pwd)'"'
local package `"`project'/stata"'
local oldplus `"`c(sysdir_plus)'"'
local plusdir `"`c(tmpdir)'/usebcch_compat_plus"'
capture mkdir `"`plusdir'"'
sysdir set PLUS `"`plusdir'"'

net install usebcch, from(`"`package'"') replace
cd `"`c(tmpdir)'"'
which usebcch
quietly findfile usebcch.ado
local installed `"`r(fn)'"'
assert strpos(lower(`"`installed'"'), "usebcch_compat_plus") > 0

/* Load the installed ado so its internal transport can be fixture-backed. */
do `"`installed'"'

tempfile credentials
tempname handle
file open `handle' using `"`credentials'"', write text replace
file write `handle' "fixture-user" _n "fixture-password" _n
file close `handle'

program drop _usebcch_copy
global UBCCH_COMPAT_PROJECT `"`project'"'
program define _usebcch_copy
    version 16.0
    args url destination
    if strpos(`"`url'"', "function=SearchSeries") {
        quietly copy `"${UBCCH_COMPAT_PROJECT}/stata/tests/fixtures/searchseries_ok.json"' ///
            `"`destination'"', replace
    }
    else {
        quietly copy `"${UBCCH_COMPAT_PROJECT}/stata/tests/fixtures/getseries_ok.json"' ///
            `"`destination'"', replace
    }
end

/* Exercise strL-backed import from callers using Stata 16 through Stata 19. */
foreach caller in 16.0 17.0 18.0 19.0 {
    version `caller': usebcch get F073.TCO.PRE.Z.D, long ///
        credentials(`"`credentials'"') clear
    assert _N == 3
    assert time[1] == mdy(12,29,2023)
    assert value[1] == 877.12
    assert missing(value[2])
    assert value_raw[2] == "NaN"
    assert spanish_name[1] == "Tipo de cambio observado"
    assert `"`r(layout)'"' == "long"
}

/* Exercise reshape wide and names sanitized through Stata 16's strtoname(). */
usebcch get F073.TCO.PRE.Z.D, names(dólar-observado) ///
    credentials(`"`credentials'"') clear
assert _N == 3
confirm variable dólar_observado
assert dólar_observado[3] == 881.46
assert `"`r(layout)'"' == "wide"

/* Exercise Unicode case folding/search and SearchSeries materialization. */
usebcch search "ENERGÍA", frequency(daily) language(es) ///
    credentials(`"`credentials'"') clear
assert _N == 1
assert series_id[1] == "TEST.UNICODE.D"
assert spanish_title[1] == "Índice, energía y producción — prueba"
assert missing(updated_at[1])
assert missing(created_at[1])

/* Stata 16 introduced frames; usebcch must affect only the current frame. */
clear
set obs 1
generate byte sentinel = 42
frame create bcch_download
frame change bcch_download
usebcch get F073.TCO.PRE.Z.D, long credentials(`"`credentials'"') clear
assert _N == 3
assert series_id[1] == "F073.TCO.PRE.Z.D"
frame change default
assert _N == 1
assert sentinel[1] == 42
frame drop bcch_download

/* Restore the caller's PLUS path for interactive execution of this test. */
cd `"`project'"'
sysdir set PLUS `"`oldplus'"'
macro drop UBCCH_COMPAT_PROJECT
display as result "usebcch compatibility: Stata 16 version-control tests passed"
