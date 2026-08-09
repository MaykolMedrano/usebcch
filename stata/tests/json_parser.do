version 16.0
clear all

do stata/usebcch_json.mata

mata:
p = ubcch_json_parse(`"{"Codigo":0,"ok":true,"missing":null,"escaped":"línea\nUnicode: \u00f1; astral: \ud83d\ude00","Series":{"seriesId":"F001","Obs":[{"indexDateString":"01-01-2024","value":"123.45","statusCode":"OK"},{"indexDateString":"02-01-2024","value":"NaN","statusCode":"ND"}]},"SeriesInfos":[{"seriesId":"F001","frequencyCode":"DAILY","spanishTitle":"Tipo de cambio"}]}"')

assert(ubcch_json_kind(p)==5)
assert(ubcch_json_number(ubcch_json_get(p,"Codigo"))==0)
assert(ubcch_json_boolean(ubcch_json_get(p,"ok"))==1)
assert(ubcch_json_isnull(ubcch_json_get(p,"missing")))
assert(ubcch_json_string(ubcch_json_get(p,"escaped"))=="línea"+char(10)+"Unicode: ñ; astral: "+uchar(128512))

s = ubcch_json_series(p,("seriesId"))
assert(rows(s)==1 & s[1,1]=="F001")

o = ubcch_json_obs(p,("indexDateString","value","statusCode"))
assert(rows(o)==2 & cols(o)==3)
assert(o[1,1]=="01-01-2024" & o[1,2]=="123.45" & o[2,3]=="ND")

i = ubcch_json_seriesinfos(p,("seriesId","frequencyCode","spanishTitle"))
assert(rows(i)==1 & i[1,3]=="Tipo de cambio")

/* Edge cases required by RFC 8259's JSON grammar. */
q = ubcch_json_parse(`"[-1,0,2.5,6.02e23,false,"",[],{}]"')
assert(ubcch_json_size(q)==8)
assert(ubcch_json_number(ubcch_json_item(q,1))==-1)
assert(ubcch_json_boolean(ubcch_json_item(q,5))==0)
assert(ubcch_json_string(ubcch_json_item(q,6))=="")

printf("usebcch JSON parser: all tests passed\n")
end
