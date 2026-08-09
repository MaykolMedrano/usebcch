version 16.0
clear all

do stata/usebcch_json.mata
do stata/usebcch_core.mata
do stata/usebcch.ado

tempfile envfile
mata:
h=fopen(st_local("envfile"),"w")
fput(h,uchar(65279)+"# UTF-8 BOM and comment")
fput(h,"IGNORED_KEY=ignored")
fput(h,"export BCCH_USER=audit+user@example.com")
fput(h,"BCCH_PASSWORD="+char(34)+" leading p@ +&=% "+uchar(241)+" "+uchar(128515)+" trailing "+char(34))
fput(h,"BCCH_PASSWORD="+char(34)+" leading p@ +&=% "+uchar(241)+" "+uchar(128515)+" trailing "+char(34))
fclose(h)
end

mata: ubcch_dotenv_auth(st_local("envfile"))
assert "`_ub_file_ok'"=="1"
mata: assert(st_local("_ub_file_user")==ubcch_urlencode("audit+user@example.com"))
mata: assert(st_local("_ub_file_pass")==ubcch_urlencode(" leading p@ +&=% "+uchar(241)+" "+uchar(128515)+" trailing "))

/* Explicit envfile() follows its own branch, independent of process values. */
_usebcch_credentials, envfile(`"`envfile'"')
assert "`_ub_auth_user'"=="audit%2Buser%40example.com"
mata: assert(st_local("_ub_auth_pass")==ubcch_urlencode(" leading p@ +&=% "+uchar(241)+" "+uchar(128515)+" trailing "))

/* The legacy two-line credentials file uses the same safe encoding. */
tempfile credentials
mata:
h=fopen(st_local("credentials"),"w")
fput(h,"audit+user@example.com")
fput(h,"p@ss +&=% "+uchar(241)+" "+uchar(128515))
fclose(h)
end
_usebcch_credentials, credentials(`"`credentials'"')
assert "`_ub_auth_user'"=="audit%2Buser%40example.com"
mata: assert(st_local("_ub_auth_pass")==ubcch_urlencode("p@ss +&=% "+uchar(241)+" "+uchar(128515)))

/* Exercise the complete URL path without making a network request. */
_usebcch_credentials, envfile(`"`envfile'"')
global UBCCH_TEST_USER `"`_ub_auth_user'"'
global UBCCH_TEST_PASS `"`_ub_auth_pass'"'
capture program drop _usebcch_copy
program define _usebcch_copy
    version 16.0
    args url destination
    assert strpos(`"`url'"',"user=$UBCCH_TEST_USER&pass=$UBCCH_TEST_PASS&")>0
    assert strpos(`"`url'"',"timeseries=TEST.SPECIAL.D")>0
    quietly copy "stata/tests/fixtures/error_invalid_credentials.json" `"`destination'"', replace
end

tempfile command_log
quietly log using `"`command_log'"', text replace name(credential_audit)
capture noisily usebcch get TEST.SPECIAL.D, envfile(`"`envfile'"') long clear
local command_rc=_rc
quietly log close credential_audit
assert `command_rc'==498

/* Neither raw nor percent-encoded password may occur in ordinary output. */
mata:
h=fopen(st_local("command_log"),"r")
s=""
while ((line=fget(h))!=J(0,0,"")) s=s+line+char(10)
fclose(h)
raw=" leading p@ +&=% "+uchar(241)+" "+uchar(128515)+" trailing "
assert(strpos(s,raw)==0)
assert(strpos(s,ubcch_urlencode(raw))==0)
end

global UBCCH_TEST_USER
global UBCCH_TEST_PASS

display as result "usebcch credential security: all tests passed"
