version 16.0
clear all
adopath ++ "."
capture mata: mata clear
mata:
string scalar ubcch_core_version()
{
    return("0.2.0")
}
string scalar ubcch_urlencode(string scalar value)
{
    return("stale-core")
}
end
do stata/usebcch.ado
_usebcch_load_mata
mata: assert(ubcch_core_version()=="0.5.0")
mata: assert(ubcch_urlencode("a b")=="a%20b")
_usebcch_load_mata

tempfile emptyenv
tempname emptyhandle
file open `emptyhandle' using `"`emptyenv'"', write text
file close `emptyhandle'

sysuse auto, clear
local original_N=_N
capture noisily usebcch get F073.TCO.PRE.Z.D, envfile(`"`emptyenv'"') clear
local rc=_rc
display "get rc=`rc'"
assert `rc'==198
assert _N==`original_N'

capture usebcch get F073.TCO.PRE.Z.D, from(2024-99-01) clear
local rc=_rc
assert `rc'==198
assert _N==`original_N'

capture usebcch search IPC, frequency(weekly) clear
local rc=_rc
assert `rc'==198
assert _N==`original_N'

display as result "usebcch ado: validation tests passed"
