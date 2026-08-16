*! usebcch 0.5.0 16aug2026
program define usebcch, rclass
    version 16.0
    gettoken subcommand 0 : 0, parse(" ,")
    local subcommand=lower("`subcommand'")
    if "`subcommand'"=="get" {
        _usebcch_get `0'
        return add
    }
    else if "`subcommand'"=="search" {
        _usebcch_search `0'
        return add
    }
    else if "`subcommand'"=="cache" {
        _usebcch_cache `0'
        return add
    }
    else if "`subcommand'"=="auth" {
        _usebcch_auth `0'
        return add
    }
    else {
        display as error "syntax: usebcch get ... | search ... | cache ... | auth ..."
        exit 198
    }
end

program define _usebcch_get, rclass
    version 16.0
    syntax anything(name=series id="series codes") [, FROM(string) TO(string) ///
        NAMES(string) LONG CLEAR TOKEN(string) CREDentials(string) ENVfile(string) ///
        FREQuency(string) AGGregate(string) VARiation(integer 0) SKIPInvalid]
    _usebcch_require_clear, `clear'
    if "`from'"!="" _usebcch_validate_date `"`from'"', option("from()")
    if "`to'"!="" _usebcch_validate_date `"`to'"', option("to()")
    if "`from'"!="" & "`to'"!="" {
        if daily("`from'","YMD")>daily("`to'","YMD") {
            display as error "from() cannot be later than to()"
            exit 198
        }
    }
    if "`long'"!="" & ("`frequency'"!="" | "`aggregate'"!="" | `variation'>0) {
        display as error "frequency(), aggregate(), and variation() require wide output"
        exit 198
    }
    if `variation'<0 {
        display as error "variation() must be a nonnegative number of months"
        exit 198
    }

    local workeropts
    if "`from'"!="" local workeropts `workeropts' from(`"`from'"')
    if "`to'"!="" local workeropts `workeropts' to(`"`to'"')
    if `"`names'"'!="" local workeropts `workeropts' names(`"`names'"')
    if "`long'"!="" local workeropts `workeropts' long
    if `"`credentials'"'!="" local workeropts `workeropts' credentials(`"`credentials'"')
    if `"`envfile'"'!="" local workeropts `workeropts' envfile(`"`envfile'"')
    if `"`token'"'!="" local workeropts `workeropts' token(`"`token'"')
    if `"`frequency'"'!="" local workeropts `workeropts' frequency(`frequency')
    if `"`aggregate'"'!="" local workeropts `workeropts' aggregate(`"`aggregate'"')
    if `variation'>0 local workeropts `workeropts' variation(`variation')
    if "`skipinvalid'"!="" local workeropts `workeropts' skipinvalid
    preserve
    capture noisily _usebcch_get_work `series', `workeropts'
    local rc=_rc
    if `rc' {
        restore
        exit `rc'
    }
    local observations=r(N)
    local layout `"`r(layout)'"'
    local failed_series `"`r(failed_series)'"'
    local successful_series=r(successful_series)
    local series_codes `"`r(series_codes)'"'
    local result_names `"`r(names)'"'
    forvalues i=1/`successful_series' {
        local result_code`i' `"`r(code`i')'"'
        local result_name`i' `"`r(name`i')'"'
        local result_title_es`i' `"`r(title_es`i')'"'
        local result_title_en`i' `"`r(title_en`i')'"'
    }
    restore, not
    local result_frequency=lower(`"`frequency'"')
    if `"`result_frequency'"'=="" local result_frequency daily

    local period_start
    local period_end
    if `observations'>0 {
        local time_format : format time
        local period_start=string(time[1],`"`time_format'"')
        local period_end=string(time[_N],`"`time_format'"')
    }
    display as result "usebcch: download complete - `observations' observations"
    display as text "Series:"
    forvalues i=1/`successful_series' {
        local shown_title `"`result_title_es`i''"'
        if `"`shown_title'"'=="" local shown_title `"`result_title_en`i''"'
        _usebcch_short_title `"`shown_title'"'
        local shown_title `"`r(title)'"'
        if `"`shown_title'"'=="" local shown_title `"`result_code`i''"'
        display as text `"  `result_name`i'' [`result_code`i'']  `shown_title'"'
    }
    if `observations'>0 {
        display as text `"Period: `period_start'-`period_end' | frequency: `result_frequency' | layout: `layout'"'
    }
    else display as text `"Period: no observations | frequency: `result_frequency' | layout: `layout'"'

    return scalar N=`observations'
    return local layout `"`layout'"'
    return local failed_series `"`failed_series'"'
    return scalar successful_series=`successful_series'
    return local frequency `"`result_frequency'"'
    return local aggregate `"`aggregate'"'
    return scalar variation=`variation'
    return local source "Banco Central de Chile - BDE"
    return local series_codes `"`series_codes'"'
    return local names `"`result_names'"'
    return local period_start `"`period_start'"'
    return local period_end `"`period_end'"'
    forvalues i=1/`successful_series' {
        return local code`i' `"`result_code`i''"'
        return local name`i' `"`result_name`i''"'
        return local title_es`i' `"`result_title_es`i''"'
        return local title_en`i' `"`result_title_en`i''"'
    }
end

program define _usebcch_short_title, rclass
    version 16.0
    args title
    local cleaned `"`title'"'
    local slash = ustrpos(`"`cleaned'"',char(92))
    if `slash'>0 local cleaned = strtrim(usubstr(`"`cleaned'"',1,`slash'-1))
    return local title `"`cleaned'"'
end

program define _usebcch_get_work, rclass
    version 16.0
    syntax anything(name=series) [, FROM(string) TO(string) NAMES(string) ///
        LONG TOKEN(string) CREDentials(string) ENVfile(string) FREQuency(string) ///
        AGGregate(string) VARiation(integer 0) SKIPInvalid]
    _usebcch_load_mata
    local credarg
    if `"`credentials'"'!="" local credarg credentials(`"`credentials'"')
    if `"`envfile'"'!="" local credarg `credarg' envfile(`"`envfile'"')
    if `"`token'"'!="" local credarg `credarg' token(`"`token'"')
    _usebcch_credentials, `credarg'
    local auth_user `"`_ub_auth_user'"'
    local auth_pass `"`_ub_auth_pass'"'
    local auth_token `"`_ub_auth_token'"'

    local series : subinstr local series "," " ", all
    local series : list retokenize series
    local count : word count `series'
    if !`count' {
        display as error "at least one series code is required"
        exit 198
    }
    local names=subinstr(`"`names'"',char(34),"",.)
    local names : list clean names
    local names : subinstr local names "," " ", all
    local names : list retokenize names
    if `"`names'"'!="" {
        local namecount : word count `names'
        if `namecount'!=`count' {
            display as error "names() must contain one name for each series (`namecount' names for `count' series)"
            exit 198
        }
    }
    forvalues nameindex=1/`count' {
        local output_name`nameindex' : word `nameindex' of `names'
    }
    local frequency=lower("`frequency'")
    if "`frequency'"!="" & !inlist("`frequency'","daily","monthly","quarterly","annual") {
        display as error "frequency() must be daily, monthly, quarterly, or annual"
        exit 198
    }
    local aggregate=subinstr(`"`aggregate'"',char(34),"",.)
    local aggregate : subinstr local aggregate "," " ", all
    local aggregate : list retokenize aggregate
    local aggcount : word count `aggregate'
    if "`aggregate'"!="" & "`frequency'"=="" {
        display as error "aggregate() requires frequency()"
        exit 198
    }
    if !inlist("`frequency'","","daily") & "`aggregate'"=="" {
        display as error "frequency() requires aggregate()"
        exit 198
    }
    if `aggcount'>1 & `aggcount'!=`count' {
        display as error "aggregate() must contain one function or one per series"
        exit 198
    }
    foreach function of local aggregate {
        if !inlist(lower("`function'"),"mean","last","first","sum","min","max") {
            display as error "unsupported aggregate `function'"
            exit 198
        }
    }

    clear
    generate double time=.
    generate double value=.
    generate str80 series_id=""
    generate strL spanish_name=""
    generate strL english_name=""
    generate str20 status=""
    generate str80 value_raw=""
    format time %td

    local index=0
    local successful_ids
    local successful_names
    local successful_aggregates
    local failed
    local successes=0
    foreach id of local series {
        local ++index
        * Respect the BCCh limit of five series requests per second.
        if `index'>1 & mod(`index'-1,5)==0 sleep 1000
        mata: ubcch_encode_locals("","", ///
            st_local("from"),st_local("to"),st_local("id"),"")
        local url "https://si3.bcentral.cl/SieteRestWS/SieteRestWS.ashx?"
        if "`auth_token'"!="" local url "`url'token=`auth_token'"
        else local url "`url'user=`auth_user'&pass=`auth_pass'"
        if "`from'"!="" local url "`url'&firstdate=`_ub_first'"
        if "`to'"!="" local url "`url'&lastdate=`_ub_last'"
        local url "`url'&timeseries=`_ub_series'&function=GetSeries"
        tempfile response
        _usebcch_copy `"`url'"' `"`response'"'
        local url ""
        mata: ubcch_check_response(st_local("response"),"get")
        if `_ub_code'==-50 & "`skipinvalid'"!="" {
            local failed `failed' `id'
            continue
        }
        _usebcch_api_error, code(`_ub_code') operation(get) description(`"`_ub_desc'"')
        local _ub_title_es
        local _ub_title_en
        mata: ubcch_import_get(st_local("response"))
        local current_title_es `"`_ub_title_es'"'
        local current_title_en `"`_ub_title_en'"'
        local ++successes
        local success_code`successes' `id'
        local successful_title_es`successes' `"`current_title_es'"'
        local successful_title_en`successes' `"`current_title_en'"'
        local successful_ids `successful_ids' `id'
        local successful_names `successful_names' `output_name`index''
        if `aggcount'==1 local successful_aggregates `successful_aggregates' `aggregate'
        else if `aggcount'>1 {
            local selected_aggregate : word `index' of `aggregate'
            local successful_aggregates `successful_aggregates' `selected_aggregate'
        }
    }
    local auth_user ""
    local auth_pass ""
    if !`successes' {
        display as error "none of the requested series was found"
        exit 498
    }
    local series `successful_ids'
    local names `successful_names'
    local aggregate `successful_aggregates'
    local count=`successes'
    forvalues nameindex=1/`count' {
        local output_name`nameindex' : word `nameindex' of `names'
    }

    if "`long'"=="" {
        local index=0
        local used
        foreach id of local series {
            local ++index
            local candidate `"`output_name`index''"'
            if `"`candidate'"'=="" local candidate series`index'
            local candidate=strtoname(`"`candidate'"')
            if `"`candidate'"'=="" local candidate series`index'
            if inlist(`"`candidate'"',"time","value","_usebcch_name") {
                local candidate series`index'
            }
            if `: list candidate in used' {
                display as error "names() produces duplicate Stata name `candidate'"
                exit 198
            }
            local used `used' `candidate'
            local wide_name`index' `candidate'
        }
        if _N {
            quietly generate str32 _usebcch_name=""
            local index=0
            foreach id of local series {
                local ++index
                local candidate `wide_name`index''
                quietly replace _usebcch_name=`"`candidate'"' if series_id==`"`id'"'
            }
            quietly isid time _usebcch_name
            quietly keep time value _usebcch_name
            quietly reshape wide value, i(time) j(_usebcch_name) string
            foreach candidate of local used {
                capture confirm variable value`candidate'
                if _rc quietly generate double `candidate'=.
                else quietly rename value`candidate' `candidate'
            }
            quietly order time `used'
            quietly sort time
        }
        else {
            quietly keep time
            foreach candidate of local used {
                quietly generate double `candidate'=.
            }
            quietly order time `used'
        }
        if "`frequency'"!="" | `variation'>0 {
            local transformopts variation(`variation')
            if "`frequency'"!="" local transformopts `transformopts' frequency(`frequency')
            if "`aggregate'"!="" local transformopts `transformopts' aggregate(`"`aggregate'"')
            _usebcch_transform `used', `transformopts'
        }
        forvalues i=1/`successes' {
            local variable `wide_name`i''
            local full_title `"`successful_title_es`i''"'
            if `"`full_title'"'=="" local full_title `"`successful_title_en`i''"'
            if `"`full_title'"'=="" local full_title `"`success_code`i''"'
            _usebcch_short_title `"`full_title'"'
            local short_title `"`r(title)'"'
            if `"`short_title'"'=="" local short_title `"`success_code`i''"'
            local short_title=usubstr(`"`short_title'"',1,80)
            capture label variable `variable' `"`short_title'"'
            char `variable'[usebcch_series] `"`success_code`i''"'
            char `variable'[usebcch_title_es] `"`successful_title_es`i''"'
            char `variable'[usebcch_title_en] `"`successful_title_en`i''"'
        }
        local layout wide
        local result_names `used'
    }
    else {
        quietly order time series_id value status value_raw spanish_name english_name
        quietly sort time series_id
        label variable series_id "BCCh series code"
        label variable spanish_name "Official Spanish series title"
        label variable english_name "Official English series title"
        local layout long
        local result_names value
    }
    local result_frequency=lower(`"`frequency'"')
    if `"`result_frequency'"'=="" local result_frequency daily
    char _dta[usebcch_source] "Banco Central de Chile - BDE"
    char _dta[usebcch_retrieved_at] `"`c(current_date)' `c(current_time)'"'
    char _dta[usebcch_series_codes] `"`series'"'
    char _dta[usebcch_frequency] `"`result_frequency'"'
    char _dta[usebcch_layout] `"`layout'"'
    char _dta[usebcch_aggregate] `"`aggregate'"'
    quietly compress
    return scalar N=_N
    return local layout `layout'
    return local failed_series `failed'
    return scalar successful_series=`successes'
    return local series_codes `"`series'"'
    return local names `"`result_names'"'
    forvalues i=1/`successes' {
        local result_name `"`wide_name`i''"'
        if `"`layout'"'=="long" local result_name value
        return local code`i' `"`success_code`i''"'
        return local name`i' `"`result_name'"'
        return local title_es`i' `"`successful_title_es`i''"'
        return local title_en`i' `"`successful_title_en`i''"'
    }
end

program define _usebcch_transform
    version 16.0
    syntax varlist(numeric), [FREQuency(string) AGGregate(string) VARiation(integer 0)]

    local requested=lower(`"`frequency'"')
    if `"`requested'"'=="" local requested daily

    if `"`requested'"'!="daily" & _N {
        tempvar period
        if `"`requested'"'=="monthly" {
            quietly generate long `period'=mofd(time)
        }
        else if `"`requested'"'=="quarterly" {
            quietly generate long `period'=qofd(time)
        }
        else if `"`requested'"'=="annual" {
            quietly generate long `period'=year(time)
        }
        quietly sort `period' time

        local collapse_specs
        local index=0
        foreach variable of local varlist {
            local ++index
            local function : word `index' of `aggregate'
            local function=lower("`function'")
            if "`function'"=="last" local function lastnm
            if "`function'"=="first" local function firstnm
            local collapse_specs `collapse_specs' (`function') `variable'
        }
        quietly collapse `collapse_specs', by(`period')
        quietly rename `period' time
        quietly sort time
    }

    if `variation'>0 & _N {
        tempfile lagdata
        tempvar lagtime
        quietly preserve
        quietly keep time `varlist'
        quietly rename time `lagtime'
        local index=0
        foreach variable of local varlist {
            local ++index
            quietly rename `variable' _usebcch_lag`index'
        }
        quietly save `"`lagdata'"', replace
        quietly restore

        quietly generate double `lagtime'=time-`variation'
        quietly merge m:1 `lagtime' using `"`lagdata'"', keep(master match) nogen
        local index=0
        foreach variable of local varlist {
            local ++index
            quietly replace `variable'=cond(!missing(`variable') & ///
                !missing(_usebcch_lag`index') & _usebcch_lag`index'!=0, ///
                `variable'/_usebcch_lag`index'-1, .)
            quietly drop _usebcch_lag`index'
        }
        quietly drop `lagtime'
        quietly sort time
    }

    if `"`requested'"'=="daily" format time %td
    else if `"`requested'"'=="monthly" format time %tm
    else if `"`requested'"'=="quarterly" format time %tq
    else format time %ty
end

program define _usebcch_search, rclass
    version 16.0
    syntax anything(name=query id="search text") [, FREQuency(string) ///
        LANGuage(string) CLEAR TOKEN(string) CREDentials(string) ENVfile(string) ///
        REGEX CACHE REFRESH]
    local query : list clean query
    _usebcch_require_clear, `clear'
    if "`frequency'"=="" local frequency all
    if "`language'"=="" local language es
    local frequency=lower("`frequency'")
    local language=lower("`language'")
    if !inlist("`frequency'","all","daily","monthly","quarterly","annual") {
        display as error "frequency() must be all, daily, monthly, quarterly, or annual"
        exit 198
    }
    if !inlist("`language'","es","en") {
        display as error "language() must be es or en"
        exit 198
    }
    if "`refresh'"!="" local cache cache

    local credarg
    if `"`credentials'"'!="" local credarg credentials(`"`credentials'"')
    if `"`envfile'"'!="" local credarg `credarg' envfile(`"`envfile'"')
    if `"`token'"'!="" local credarg `credarg' token(`"`token'"')
    preserve
    capture noisily _usebcch_search_work `query', frequency(`frequency') ///
        language(`language') `credarg' `regex' `cache' `refresh'
    local rc=_rc
    if `rc' {
        restore
        exit `rc'
    }
    local observations=r(N)
    local cache_hits=r(cache_hits)
    local downloads=r(downloads)
    restore, not
    return scalar N=`observations'
    return scalar cache_hits=`cache_hits'
    return scalar downloads=`downloads'
end

program define _usebcch_search_work, rclass
    version 16.0
    syntax anything(name=query) [, FREQuency(string) LANGuage(string) ///
        TOKEN(string) CREDentials(string) ENVfile(string) REGEX CACHE REFRESH]
    _usebcch_load_mata
    local credarg
    if `"`credentials'"'!="" local credarg credentials(`"`credentials'"')
    if `"`envfile'"'!="" local credarg `credarg' envfile(`"`envfile'"')
    if `"`token'"'!="" local credarg `credarg' token(`"`token'"')
    local frequencies=cond("`frequency'"=="all", ///
        "DAILY MONTHLY QUARTERLY ANNUAL",upper("`frequency'"))
    local auth_ready=0
    local cache_hits=0
    local downloads=0
    if "`cache'"!="" {
        _usebcch_cache_path
        local cachedir `"`r(path)'"'
    }

    clear
    generate str80 series_id=""
    generate str12 frequency=""
    generate strL spanish_title=""
    generate strL english_title=""
    foreach variable in first_observation last_observation updated_at created_at {
        generate double `variable'=.
        format `variable' %tdCCYY-NN-DD
    }

    local index=0
    local count : word count `frequencies'
    foreach freq of local frequencies {
        local ++index
        local cachefile `"`cachedir'/catalog_`=lower("`freq'")'.dta"'
        if "`cache'"!="" & "`refresh'"=="" {
            capture confirm file `"`cachefile'"'
            if !_rc {
                append using `"`cachefile'"'
                local ++cache_hits
                continue
            }
        }
        if !`auth_ready' {
            _usebcch_credentials, `credarg'
            local auth_user `"`_ub_auth_user'"'
            local auth_pass `"`_ub_auth_pass'"'
            local auth_token `"`_ub_auth_token'"'
            local auth_ready=1
        }
        mata: ubcch_encode_locals("","", ///
            "","","",st_local("freq"))
        local url "https://si3.bcentral.cl/SieteRestWS/SieteRestWS.ashx?"
        if "`auth_token'"!="" local url "`url'token=`auth_token'"
        else local url "`url'user=`auth_user'&pass=`auth_pass'"
        local url "`url'&frequency=`_ub_frequency'&function=SearchSeries"
        tempfile response
        _usebcch_copy `"`url'"' `"`response'"'
        local url ""
        mata: ubcch_import_search(st_local("response"))
        _usebcch_api_error, code(`_ub_code') operation(search) description(`"`_ub_desc'"')
        local ++downloads
        if "`cache'"!="" {
            preserve
            keep if frequency=="`freq'"
            save `"`cachefile'"', replace
            restore
        }
    }
    local auth_user ""
    local auth_pass ""

    local title=cond("`language'"=="es","spanish_title","english_title")
    if "`regex'"!="" {
        capture keep if ustrregexm(`title',`"(?i)`query'"')
        if _rc {
            display as error "invalid regular expression"
            exit 198
        }
    }
    else keep if ustrpos(ustrlower(`title'),ustrlower(`"`query'"'))
    order series_id frequency spanish_title english_title first_observation ///
        last_observation updated_at created_at
    sort frequency series_id
    quietly compress
    return scalar N=_N
    return scalar cache_hits=`cache_hits'
    return scalar downloads=`downloads'
end

program define _usebcch_cache_path, rclass
    version 16.0
    local path `"`c(sysdir_personal)'usebcch_cache"'
    capture mkdir `"`path'"'
    return local path `"`path'"'
end

program define _usebcch_cache, rclass
    version 16.0
    syntax anything(name=action)
    local action=lower(strtrim(`"`action'"'))
    _usebcch_cache_path
    local cachedir `"`r(path)'"'
    local count=0
    local cached
    if "`action'"=="clear" {
        foreach frequency in daily monthly quarterly annual {
            capture erase `"`cachedir'/catalog_`frequency'.dta"'
        }
        display as result "usebcch catalog cache cleared"
    }
    else if "`action'"=="status" {
        foreach frequency in daily monthly quarterly annual {
            capture confirm file `"`cachedir'/catalog_`frequency'.dta"'
            if !_rc {
                local ++count
                local cached `cached' `frequency'
                display as text "`frequency': cached"
            }
            else display as text "`frequency': not cached"
        }
    }
    else {
        display as error "syntax: usebcch cache clear | usebcch cache status"
        exit 198
    }
    return scalar N=`count'
    return local frequencies `cached'
    return local cache_dir `"`cachedir'"'
end

program define _usebcch_auth_path, rclass
    version 16.0
    local directory `"`c(sysdir_personal)'usebcch"'
    capture mkdir `"`directory'"'
    return local directory `"`directory'"'
    return local file `"`directory'/auth_envfile.txt"'
end

program define _usebcch_auth, rclass
    version 16.0
    syntax anything(name=action) [, ENVfile(string)]
    local action=lower(strtrim(`"`action'"'))
    if !inlist(`"`action'"',"set","status","clear") {
        display as error "syntax: usebcch auth set, envfile(filename) | status | clear"
        exit 198
    }
    if `"`action'"'!="set" & `"`envfile'"'!="" {
        display as error "envfile() is allowed only with usebcch auth set"
        exit 198
    }

    _usebcch_auth_path
    local config_file `"`r(file)'"'
    if `"`action'"'=="set" {
        if strtrim(`"`envfile'"')=="" {
            display as error "usebcch auth set requires envfile()"
            exit 198
        }
        local selected=subinstr(strtrim(`"`envfile'"'),"\","/",.)
        if substr(`"`selected'"',1,1)!="/" & substr(`"`selected'"',2,1)!=":" {
            local current=subinstr(c(pwd),"\","/",.)
            local selected `"`current'/`selected'"'
        }
        capture confirm file `"`selected'"'
        if _rc {
            display as error "envfile() was not found"
            exit 601
        }
        _usebcch_load_mata
        mata: ubcch_dotenv_auth(st_local("selected"))
        if !real(`"`_ub_file_ok'"') {
            display as error "envfile() must define BCCH_TOKEN or BCCH_USER and BCCH_PASSWORD"
            exit 198
        }
        tempname config_handle
        capture file open `config_handle' using `"`config_file'"', ///
            write text replace
        if _rc {
            display as error "could not write the usebcch auth configuration"
            exit 603
        }
        file write `config_handle' `"`selected'"' _n
        file close `config_handle'
        display as result "usebcch credential file registered"
        display as text `"`selected'"'
        return scalar configured=1
        return scalar valid=1
        return local action "set"
        return local envfile `"`selected'"'
        return local config_file `"`config_file'"'
        exit
    }

    if `"`action'"'=="clear" {
        capture erase `"`config_file'"'
        display as result "usebcch credential-file registration cleared"
        return scalar configured=0
        return scalar valid=0
        return local action "clear"
        return local config_file `"`config_file'"'
        exit
    }

    local configured=0
    local valid=0
    local selected
    tempname config_handle
    capture file open `config_handle' using `"`config_file'"', read text
    if !_rc {
        file read `config_handle' selected
        file close `config_handle'
        local configured=(`"`selected'"'!="")
    }
    if `configured' {
        capture confirm file `"`selected'"'
        if !_rc {
            _usebcch_load_mata
            mata: ubcch_dotenv_auth(st_local("selected"))
            local valid=real(`"`_ub_file_ok'"')
        }
    }
    display as text "configured: " cond(`configured',"yes","no")
    if `configured' {
        display as text "valid: " cond(`valid',"yes","no")
        display as text `"envfile: `selected'"'
    }
    return scalar configured=`configured'
    return scalar valid=`valid'
    return local action "status"
    return local envfile `"`selected'"'
    return local config_file `"`config_file'"'
end

program define _usebcch_load_mata
    version 16.0

    capture mata: assert(ubcch_core_version()=="0.5.0")
    if !_rc exit

    /* Ado updates do not clear compiled Mata functions.  Drop only this
       package's core API so an older in-memory implementation cannot be mixed
       with the current dataset schema.  The JSON parser can remain loaded. */
    foreach function in ubcch_core_version ubcch_urlencode ubcch_dotenv_auth ///
            ubcch_required_member ubcch_validate_envelope ///
            ubcch_require_string ubcch_encode_locals ubcch_read_text ///
            ubcch_parse_file ubcch_check_response ubcch_daily ///
            ubcch_import_get ubcch_import_search {
        capture mata: mata drop `function'()
    }

    capture mata: ubcch_json_parse("{}")
    if _rc {
        quietly findfile usebcch_json.mata
        quietly do `"`r(fn)'"'
    }
    quietly findfile usebcch_core.mata
    quietly do `"`r(fn)'"'
end

program define _usebcch_credentials
    version 16.0
    syntax [, TOKEN(string) CREDentials(string) ENVfile(string)]
    if `"`credentials'"'!="" & `"`envfile'"'!="" {
        display as error "credentials() and envfile() may not be combined"
        exit 198
    }
    if `"`token'"'!="" & (`"`credentials'"'!="" | `"`envfile'"'!="") {
        display as error "token() cannot be combined with credentials() or envfile()"
        exit 198
    }

    local token=trim(`"`token'"')
    local user
    local password

    if `"`token'"'!="" {
        mata: st_local("_ub_encoded_token",ubcch_urlencode(st_local("token")))
        c_local _ub_auth_token `"`_ub_encoded_token'"'
        c_local _ub_auth_user ""
        c_local _ub_auth_pass ""
        exit
    }

    if `"`credentials'"'!="" {
        tempname handle
        capture file open `handle' using `"`credentials'"', read text
        if _rc {
            display as error "could not read credentials() file"
            exit 601
        }
        file read `handle' user
        file read `handle' password
        file close `handle'
        if `"`password'"'=="" {
            local token=trim(`"`user'"')
            mata: st_local("_ub_encoded_token",ubcch_urlencode(st_local("token")))
            c_local _ub_auth_token `"`_ub_encoded_token'"'
            c_local _ub_auth_user ""
            c_local _ub_auth_pass ""
            exit
        }
    }
    else if `"`envfile'"'!="" {
        mata: ubcch_dotenv_auth(st_local("envfile"))
        if !real(`"`_ub_file_ok'"') {
            display as error "envfile() must define BCCH_TOKEN or BCCH_USER and BCCH_PASSWORD"
            exit 198
        }
        c_local _ub_auth_token `"`_ub_file_token'"'
        c_local _ub_auth_user `"`_ub_file_user'"'
        c_local _ub_auth_pass `"`_ub_file_pass'"'
        exit
    }
    else {
        local token : environment BCCH_TOKEN
        if `"`token'"'!="" {
            mata: st_local("_ub_encoded_token",ubcch_urlencode(st_local("token")))
            c_local _ub_auth_token `"`_ub_encoded_token'"'
            c_local _ub_auth_user ""
            c_local _ub_auth_pass ""
            exit
        }

        local user : environment BCCH_USER
        local password : environment BCCH_PASSWORD
        if (`"`user'"'=="" | `"`password'"'=="") {
            capture confirm file ".env"
            if !_rc {
                mata: ubcch_dotenv_auth(".env")
                if real(`"`_ub_file_ok'"') {
                    c_local _ub_auth_token `"`_ub_file_token'"'
                    c_local _ub_auth_user `"`_ub_file_user'"'
                    c_local _ub_auth_pass `"`_ub_file_pass'"'
                    exit
                }
            }
            _usebcch_auth_path
            local auth_config `"`r(file)'"'
            tempname auth_handle
            capture file open `auth_handle' using `"`auth_config'"', read text
            if !_rc {
                file read `auth_handle' registered_envfile
                file close `auth_handle'
                capture confirm file `"`registered_envfile'"'
                if !_rc {
                    mata: ubcch_dotenv_auth(st_local("registered_envfile"))
                    if real(`"`_ub_file_ok'"') {
                        c_local _ub_auth_token `"`_ub_file_token'"'
                        c_local _ub_auth_user `"`_ub_file_user'"'
                        c_local _ub_auth_pass `"`_ub_file_pass'"'
                        exit
                    }
                }
            }
        }
    }

    if `"`user'"'=="" | `"`password'"'=="" {
        display as error "credentials not found; set BCCH_TOKEN, run usebcch auth set, envfile(filename), or define BCCH_USER/BCCH_PASSWORD"
        exit 198
    }
    mata: st_local("_ub_encoded_user",ubcch_urlencode(st_local("user")))
    mata: st_local("_ub_encoded_pass",ubcch_urlencode(st_local("password")))
    c_local _ub_auth_token ""
    c_local _ub_auth_user `"`_ub_encoded_user'"'
    c_local _ub_auth_pass `"`_ub_encoded_pass'"'
end
program define _usebcch_copy
    version 16.0
    args url destination
    local rc=1
    forvalues attempt=1/3 {
        capture quietly copy `"`url'"' `"`destination'"', replace
        local rc=_rc
        if !`rc' continue, break
    }
    if `rc' {
        display as error "could not download data from the BCCh API"
        exit `rc'
    }
end

program define _usebcch_api_error
    version 16.0
    syntax, CODE(real) OPERATION(string) [DESCRIPTION(string asis)]
    if `code'==0 exit
    if `code'==-5 display as error "invalid BCCh API token or legacy credentials"
    else if `code'==-50 & "`operation'"=="get" display as error "series not found"
    else if `code'==-1 & "`operation'"=="get" display as error "invalid date"
    else if `code'==-1 & "`operation'"=="search" display as error "invalid frequency"
    else display as error `"BCCh API error `code': `description'"'
    exit 498
end

program define _usebcch_require_clear
    version 16.0
    syntax [, CLEAR]
    if "`clear'"=="" & (c(k)>0 | c(N)>0) {
        display as error "no; data in memory would be lost"
        display as error "specify clear to replace the current dataset"
        exit 4
    }
end

program define _usebcch_validate_date
    version 16.0
    syntax anything(name=value) [, OPTION(string)]
    local value : list clean value
    if `"`value'"'!="" & (strlen(`"`value'"')!=10 | missing(daily(`"`value'"',"YMD"))) {
        display as error "`option' must use YYYY-MM-DD format"
        exit 198
    }
end
