version 16.0
clear all
set more off
capture log close _all
log using distribution.log, replace text

args release_dir
if `"`release_dir'"'=="" {
    display as error "syntax: do stata/tests/distribution.do release_directory"
    exit 198
}
local release_dir=subinstr(`"`release_dir'"',char(92),"/",.)
if substr(`"`release_dir'"',1,1)!="/" & substr(`"`release_dir'"',2,1)!=":" {
    local release_dir `"`c(pwd)'/`release_dir'"'
}

tempname installation_id
local personal `"`c(tmpdir)'/usebcch-dist-`installation_id'"'
capture mkdir `"`personal'"'
sysdir set PERSONAL `"`personal'/"'
net set ado PERSONAL
discard
cd `"`personal'"'

local package_dir `"`release_dir'/stata"'
net install usebcch, from(`"`package_dir'"') replace
which usebcch
foreach file in usebcch.ado usebcch.sthlp usebcch_json.mata ///
        usebcch_core.mata {
    findfile `file'
}
help usebcch
usebcch auth status
assert r(configured)==0

display as result "usebcch generated distribution test passed"
log close
