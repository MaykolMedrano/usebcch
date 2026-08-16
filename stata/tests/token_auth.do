version 16.0
clear all

do stata/usebcch_json.mata
do stata/usebcch_core.mata
do stata/usebcch.ado

tempfile envfile
file open env_handle using `"`envfile'"', write text replace
file write `env_handle' "BCCH_TOKEN=test+token@example.com" _n
file close `env_handle'

mata: ubcch_dotenv_auth(st_local("envfile"))
assert "`_ub_file_ok'"=="1"
mata: assert(st_local("_ub_file_token")==ubcch_urlencode("test+token@example.com"))

_usebcch_credentials, envfile(`"`envfile'"')
assert "`_ub_auth_token'"=="test%2Btoken%40example.com"
assert "`_ub_auth_user'"==""

global UBCCH_TEST_TOKEN "`_ub_auth_token'"
capture program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    assert strpos(`"`url'"',"token=$UBCCH_TEST_TOKEN&")>0
    assert strpos(`"`url'"',"user=")==0
    assert strpos(`"`url'", "timeseries=F073.TCO.PRE.Z.D")>0
    quietly copy "stata/tests/fixtures/getseries_ok.json" `"`destination'"', replace
end

capture noisily usebcch get F073.TCO.PRE.Z.D, envfile(`"`envfile'"') clear
assert _rc==0

tempfile tokenfile
file open token_handle using `"`tokenfile'"', write text replace
file write `token_handle' "test+token@example.com" _n
file close `token_handle'
_usebcch_credentials, credentials(`"`tokenfile'"')
assert "`_ub_auth_token'"=="test%2Btoken%40example.com"

global UBCCH_TEST_TOKEN
display as result "usebcch token authentication: all tests passed"