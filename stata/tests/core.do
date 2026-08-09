version 16.0
clear all
do stata/usebcch_json.mata
do stata/usebcch_core.mata

clear
generate double time=.
format time %td
generate double value=.
generate str80 series_id=""
generate strL spanish_name=""
generate strL english_name=""
generate str20 status=""
generate str40 value_raw=""
mata: ubcch_import_get("stata/tests/fixtures/getseries_ok.json")
assert _N==3
assert `"`_ub_title_es'"'=="Tipo de cambio observado"
assert `"`_ub_title_en'"'=="Observed exchange rate"
assert time[1]==mdy(12,29,2023)
local time_format : format time
assert `"`time_format'"'=="%td"
assert value[1]==877.12
assert missing(value[2])
assert status[2]=="ND"
assert spanish_name[1]=="Tipo de cambio observado"

clear
generate str80 series_id=""
generate str12 frequency=""
generate strL spanish_title=""
generate strL english_title=""
foreach v in first_observation last_observation updated_at created_at {
    generate double `v'=.
}
mata: ubcch_import_search("stata/tests/fixtures/searchseries_ok.json")
assert _N==2
assert series_id[1]=="F073.TCO.PRE.Z.D"
assert frequency[1]=="DAILY"
assert first_observation[1]==mdy(1,2,1984)
assert missing(updated_at[2])

mata: assert(ubcch_urlencode("a+b@example.com") == "a%2Bb%40example.com")
display as result "usebcch core: all tests passed"
