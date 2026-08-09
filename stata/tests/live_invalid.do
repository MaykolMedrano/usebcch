version 16.0
clear all
adopath ++ "."
do stata/usebcch.ado
sysuse auto, clear
local original_N=_N
capture noisily usebcch get F073.TCO.PRE.Z.D, clear
local rc=_rc
assert `rc'==498
assert _N==`original_N'
display as result "usebcch live transport/error test passed"
