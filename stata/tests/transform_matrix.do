version 16.0
clear all
do stata/usebcch.ado

input str10 datestr meanv lastv firstv sumv minv maxv
"2024-01-30" 10 100 7  1 9  4
"2024-01-31" 20 200 8  2 3 14
"2024-02-28" 30 300 9  3 8  2
"2024-02-29" 50 400 10 4 1 12
end
generate double time=daily(datestr,"YMD")
drop datestr
format time %td
_usebcch_transform meanv lastv firstv sumv minv maxv, ///
    frequency(monthly) aggregate(mean last first sum min max)
assert _N==2
assert meanv[1]==15 & meanv[2]==40
assert lastv[1]==200 & lastv[2]==400
assert firstv[1]==7 & firstv[2]==9
assert sumv[1]==3 & sumv[2]==7
assert minv[1]==3 & minv[2]==1
assert maxv[1]==14 & maxv[2]==12
assert time[1]==ym(2024,1) & time[2]==ym(2024,2)
local monthly_format : format time
assert `"`monthly_format'"'=="%tm"
tsset time

clear
input str10 datestr value
"2023-01-31" 100
"2024-01-31" 121
end
generate double time=daily(datestr,"YMD")
drop datestr
format time %td
_usebcch_transform value, frequency(monthly) aggregate(last) variation(12)
assert missing(value[1])
assert reldif(value[2],.21)<1e-6
assert time[1]==ym(2023,1) & time[2]==ym(2024,1)

clear
input str10 datestr value
"2024-01-31" 1
"2024-04-30" 2
"2025-01-31" 3
end
generate double time=daily(datestr,"YMD")
drop datestr
_usebcch_transform value, frequency(quarterly) aggregate(last) variation(1)
assert time[1]==yq(2024,1)
assert time[2]==yq(2024,2)
assert missing(value[1])
assert value[2]==1
assert missing(value[3])
local quarterly_format : format time
assert `"`quarterly_format'"'=="%tq"

clear
input str10 datestr value
"2023-01-01" 1
"2023-12-31" 2
"2024-06-30" 4
end
generate double time=daily(datestr,"YMD")
drop datestr
_usebcch_transform value, frequency(annual) aggregate(sum)
assert _N==2
assert time[1]==2023 & time[2]==2024
assert value[1]==3 & value[2]==4
local annual_format : format time
assert `"`annual_format'"'=="%ty"

display as result "usebcch transform matrix tests passed"
