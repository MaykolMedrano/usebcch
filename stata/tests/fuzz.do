version 16.0
clear all

do stata/usebcch_json.mata
do stata/usebcch_core.mata

/* Valid JSON: every escape, Unicode BMP/astral, whitespace and extra keys. */
mata:
p = ubcch_json_parse(`" { "s" : "quote: \"; slash: \/; backslash: \\; controls: \b\f\n\r\t", "bmp":"\u00f1", "astral":"\ud83d\ude03", "extra":{"deep":[true,false,null,-0,1.25e-2]}} "')
assert(ubcch_json_string(ubcch_json_get(p,"bmp"))==uchar(241))
assert(ubcch_json_string(ubcch_json_get(p,"astral"))==uchar(128515))
assert(ubcch_json_kind(ubcch_json_get(p,"extra"))==5)

/* RFC 3986 encoding, including the UTF-8 representation of Unicode. */
assert(ubcch_urlencode("AZaz09-._~")=="AZaz09-._~")
assert(ubcch_urlencode("p@ss +&=% /?:")=="p%40ss%20%2B%26%3D%25%20%2F%3F%3A")
assert(ubcch_urlencode("n"+uchar(771)+"and"+uchar(250)+" "+uchar(128515))=="n%CC%83and%C3%BA%20%F0%9F%98%83")
end

/* Truncation and malformed grammar must consistently be rejected. */
capture mata: ubcch_json_parse("{")
assert _rc==610
capture mata: ubcch_json_parse("[")
assert _rc==610
capture mata: ubcch_json_parse(`""unterminated"')
assert _rc==610
capture mata: ubcch_json_parse("[1,")
assert _rc==610
capture mata: ubcch_json_parse(`"{""a"":"')
assert _rc==610

capture mata: ubcch_json_parse(`""\ud83d""')
assert _rc==610
capture mata: ubcch_json_parse(`""\ude03""')
assert _rc==610
capture mata: ubcch_json_parse(`""\ud83d\u0041""')
assert _rc==610
capture mata: ubcch_json_parse(`""\uZZZZ""')
assert _rc==610
capture mata: ubcch_json_parse(char(34)+char(255)+char(34))
assert _rc==610
capture mata: ubcch_json_parse(`"[01]"')
assert _rc==610
capture mata: ubcch_json_parse(`"[1.]"')
assert _rc==610
capture mata: ubcch_json_parse(`"[+1]"')
assert _rc==610
capture mata: ubcch_json_parse(`"[NaN]"')
assert _rc==610
capture mata: ubcch_json_parse(`"{""a"":1,}"')
assert _rc==610
capture mata: ubcch_json_parse(`"{""Codigo"":0,""Codigo"":-5}"')
assert _rc==610
capture mata: ubcch_json_parse(`"[1,]"')
assert _rc==610
capture mata: ubcch_json_parse(`"true false"')
assert _rc==610

/* Moderate nesting is valid; hostile recursion is capped before stack exhaustion. */
mata:
nested="0"
for (i=1; i<=64; i++) nested="["+nested+"]"
p=ubcch_json_parse(nested)
assert(ubcch_json_kind(p)==4)
deep="0"
for (i=1; i<=600; i++) deep="["+deep+"]"
end
capture mata: ubcch_json_parse(deep)
assert _rc==610

/* Unknown future keys are tolerated; required schema/type errors are not. */
clear
generate double time=.
generate double value=.
generate str80 series_id=""
generate strL spanish_name=""
generate strL english_name=""
generate str20 status=""
generate str80 value_raw=""
mata: ubcch_import_get("stata/tests/fixtures/getseries_extra_keys.json")
assert _N==1
assert series_id=="TEST.EXTRA.D"
assert value==1.5

clear
generate double time=.
generate double value=.
generate str80 series_id=""
generate strL spanish_name=""
generate strL english_name=""
generate str20 status=""
generate str80 value_raw=""
capture mata: ubcch_import_get("stata/tests/fixtures/getseries_wrong_types.json")
assert _rc==610
assert _N==0
capture mata: ubcch_import_get("stata/tests/fixtures/getseries_wrong_observation.json")
assert _rc==610
assert _N==0
capture mata: ubcch_import_search("stata/tests/fixtures/searchseries_wrong_types.json")
assert _rc==610
capture mata: ubcch_check_response("stata/tests/fixtures/response_missing_required.json","get")
assert _rc==610

display as result "usebcch fuzz/security: all tests passed"
