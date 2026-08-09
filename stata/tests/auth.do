version 16.0
clear all
set more off
adopath ++ "."
do stata/usebcch.ado

local project `"`c(pwd)'"'
local oldpersonal `"`c(sysdir_personal)'"'
tempfile personalmarker registered_env invalid_env
local expected_env=subinstr(`"`registered_env'"',"\","/",.)
local personal `"`personalmarker'_auth_dir"'
local workdir `"`personal'/work"'
mkdir `"`personal'"'
mkdir `"`workdir'"'
sysdir set PERSONAL `"`personal'/"'

tempname env_handle
file open `env_handle' using `"`registered_env'"', write text
file write `env_handle' "BCCH_USER=registered-user" _n ///
    "BCCH_PASSWORD='registered pass'" _n
file close `env_handle'

cd `"`workdir'"'
usebcch auth set, envfile(`"`registered_env'"')
assert r(configured)==1
assert r(valid)==1
local config_file `"`r(config_file)'"'

/* The persistent file stores only the selected path, never credentials. */
tempname config_handle
file open `config_handle' using `"`config_file'"', read text
file read `config_handle' stored_path
file close `config_handle'
assert `"`stored_path'"'==`"`expected_env'"'
assert strpos(`"`stored_path'"',"registered-user")==0
assert strpos(`"`stored_path'"',"registered pass")==0

sysuse auto, clear
local original_N=_N
usebcch auth status
assert _N==`original_N'
assert r(configured)==1
assert r(valid)==1
assert `"`r(envfile)'"'==`"`expected_env'"'

/* With no explicit option and no local .env, the registered file is used. */
_usebcch_credentials
assert `"`_ub_auth_user'"'=="registered-user"
assert `"`_ub_auth_pass'"'=="registered%20pass"

global UBCCH_AUTH_PROJECT `"`project'"'
capture program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    assert strpos(`"`url'"',"user=registered-user&pass=registered%20pass&")>0
    quietly copy `"${UBCCH_AUTH_PROJECT}/stata/tests/fixtures/getseries_ok.json"' ///
        `"`destination'"', replace
end
usebcch get F073.TCO.PRE.Z.D, names(dolar) clear
assert _N==3
assert dolar[1]==877.12

/* An invalid replacement is rejected without overwriting the valid setting. */
file open `env_handle' using `"`invalid_env'"', write text
file write `env_handle' "BCCH_USER=incomplete" _n
file close `env_handle'
capture noisily usebcch auth set, envfile(`"`invalid_env'"')
assert _rc==198
quietly usebcch auth status
assert r(configured)==1 & r(valid)==1
assert `"`r(envfile)'"'==`"`expected_env'"'

usebcch auth clear
assert r(configured)==0
usebcch auth status
assert r(configured)==0 & r(valid)==0

cd `"`project'"'
sysdir set PERSONAL `"`oldpersonal'"'
macro drop UBCCH_AUTH_PROJECT
display as result "usebcch auth registration tests passed"
