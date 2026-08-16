version 16.0
set more off

foreach suite in json_parser core ado integration_fixture empty_schema fuzz ///
        security_credentials token_auth auth compatibility features transform_matrix cache package {
    display as text "[usebcch] running stata/tests/`suite'.do"
    capture noisily do `"stata/tests/`suite'.do"'
    local rc=_rc
    if `rc' {
        display as error "[usebcch] stata/tests/`suite'.do failed with r(`rc')"
        exit `rc'
    }
}

display as result "usebcch offline suite: all tests passed"
