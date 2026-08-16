/* Native Mata helpers for usebcch. Requires usebcch_json.mata. */

mata:

string scalar ubcch_core_version()
{
    return("0.5.1")
}

string scalar ubcch_urlencode(string scalar value)
{
    real rowvector bytes
    real scalar i, b
    string scalar out, c, hex
    bytes=ascii(value)
    out=""
    hex="0123456789ABCDEF"
    for (i=1; i<=cols(bytes); i++) {
        b=bytes[i]
        c=char(b)
        if ((b>=65 & b<=90) | (b>=97 & b<=122) |
            (b>=48 & b<=57) | strpos("-._~",c)) out=out+c
        else out=out+"%"+substr(hex,floor(b/16)+1,1)+substr(hex,mod(b,16)+1,1)
    }
    return(out)
}

void ubcch_dotenv_auth(string scalar filename)
{
    real scalar handle, equals, firstline
    string scalar line, key, value, token, apikey, user, password, first, last
    handle=fopen(filename,"r")
    if (handle<0) {
        errprintf("usebcch: no se pudo leer envfile()\n")
        exit(601)
    }
    token=""
    apikey=""
    user=""
    password=""
    firstline=1
    while ((line=fget(handle))!=J(0,0,"")) {
        if (firstline & usubstr(line,1,1)==uchar(65279)) line=usubstr(line,2,.)
        firstline=0
        line=strtrim(line)
        if (!strlen(line) | substr(line,1,1)=="#") continue
        if (substr(line,1,7)=="export ") line=strtrim(substr(line,8,.))
        equals=strpos(line,"=")
        if (!equals) continue
        key=strtrim(substr(line,1,equals-1))
        value=strtrim(substr(line,equals+1,.))
        if (strlen(value)>=2) {
            first=substr(value,1,1)
            last=substr(value,strlen(value),1)
            if ((first==char(34) & last==char(34)) | (first=="'" & last=="'"))
                value=substr(value,2,strlen(value)-2)
        }
        if (key=="BCCH_TOKEN") token=value
        if (key=="APIKEY") apikey=value
        if (key=="BCCH_USER") user=value
        if (key=="BCCH_PASSWORD") password=value
    }
    fclose(handle)
    if (!strlen(token)) token=apikey
    st_local("_ub_file_token",ubcch_urlencode(token))
    st_local("_ub_file_user",ubcch_urlencode(user))
    st_local("_ub_file_pass",ubcch_urlencode(password))
    st_local("_ub_file_ok",strofreal(strlen(token)>0 | (strlen(user)>0 & strlen(password)>0)))
}

pointer(struct ubcch_json_value scalar) scalar ubcch_required_member(
    pointer(struct ubcch_json_value scalar) scalar parent,
    string scalar key, real scalar kind, string scalar context)
{
    pointer(struct ubcch_json_value scalar) scalar item
    item=ubcch_json_get(parent,key)
    if (item==NULL) {
        errprintf("usebcch: malformed %s response (%s is missing)\n",
                  context,key)
        exit(610)
    }
    if (ubcch_json_kind(item)!=kind) {
        errprintf("usebcch: malformed %s response (%s has an invalid type)\n",
                  context,key)
        exit(610)
    }
    return(item)
}

void ubcch_validate_envelope(pointer(struct ubcch_json_value scalar) scalar root,
                             string scalar context)
{
    pointer(struct ubcch_json_value scalar) scalar item
    real scalar code
    if (root==NULL) {
        errprintf("usebcch: malformed %s response (object expected)\n",context)
        exit(610)
    }
    if (ubcch_json_kind(root)!=5) {
        errprintf("usebcch: malformed %s response (object expected)\n",context)
        exit(610)
    }
    item=ubcch_required_member(root,"Codigo",2,context)
    code=ubcch_json_number(item)
    if (missing(code) | code!=trunc(code)) {
        errprintf("usebcch: malformed %s response (Codigo must be an integer)\n",
                  context)
        exit(610)
    }
    item=ubcch_required_member(root,"Descripcion",3,context)
    item=ubcch_required_member(root,"Series",5,context)
    item=ubcch_required_member(root,"SeriesInfos",4,context)
}

void ubcch_require_string(pointer(struct ubcch_json_value scalar) scalar parent,
                          string scalar key, string scalar context)
{
    pointer(struct ubcch_json_value scalar) scalar item
    item=ubcch_required_member(parent,key,3,context)
}

void ubcch_encode_locals(string scalar user, string scalar password,
                         string scalar first, string scalar last,
                         string scalar series, string scalar frequency)
{
    st_local("_ub_user",ubcch_urlencode(user))
    st_local("_ub_pass",ubcch_urlencode(password))
    st_local("_ub_first",ubcch_urlencode(first))
    st_local("_ub_last",ubcch_urlencode(last))
    st_local("_ub_series",ubcch_urlencode(series))
    st_local("_ub_frequency",ubcch_urlencode(frequency))
}

string scalar ubcch_read_text(string scalar filename)
{
    string scalar source, line
    string colvector lines
    real scalar handle, n, capacity
    handle=fopen(filename,"r")
    if (handle<0) {
        errprintf("usebcch: no se pudo leer la respuesta del servicio\n")
        exit(601)
    }
    n=0
    capacity=1024
    lines=J(capacity,1,"")
    while ((line=fget(handle))!=J(0,0,"")) {
        n=n+1
        if (n>capacity) {
            lines=lines\J(capacity,1,"")
            capacity=2*capacity
        }
        lines[n]=line
    }
    fclose(handle)
    if (!n) {
        errprintf("usebcch: el servicio devolvió una respuesta vacía\n")
        exit(610)
    }
    source=invtokens(lines[1..n]',char(10))
    if (usubstr(source,1,1)==uchar(65279)) source=usubstr(source,2,.)
    if (ustrinvalidcnt(source)) source=ustrfrom(source,"windows-1252",1)
    return(source)
}

pointer(struct ubcch_json_value scalar) scalar ubcch_parse_file(string scalar filename)
{
    return(ubcch_json_parse(ubcch_read_text(filename)))
}

void ubcch_check_response(string scalar filename, string scalar operation)
{
    pointer(struct ubcch_json_value scalar) scalar root, item
    real scalar code
    string scalar description
    root=ubcch_parse_file(filename)
    ubcch_validate_envelope(root,operation)
    item=ubcch_json_get(root,"Codigo")
    if (item==NULL | ubcch_json_kind(item)!=2) {
        errprintf("usebcch: respuesta sin un Codigo válido\n")
        exit(610)
    }
    code=ubcch_json_number(item)
    item=ubcch_json_get(root,"Descripcion")
    description=item==NULL ? "" : ubcch_json_string(item)
    st_local("_ub_code",strofreal(code,"%18.0g"))
    st_local("_ub_desc",description)
    st_local("_ub_operation",operation)
}

real scalar ubcch_daily(string scalar value)
{
    real rowvector parts
    if (!ustrregexm(value,"^([0-9]{2})-([0-9]{2})-([0-9]{4})$")) return(.)
    parts=strtoreal((ustrregexs(1),ustrregexs(2),ustrregexs(3)))
    return(mdy(parts[2],parts[1],parts[3]))
}

void ubcch_import_get(string scalar filename)
{
    pointer(struct ubcch_json_value scalar) scalar root, series, observations
    pointer(struct ubcch_json_value scalar) scalar item, observation
    string matrix obs
    string scalar id, title_es, title_en
    real colvector dates, values
    real scalar i, n, firstobs

    root=ubcch_parse_file(filename)
    ubcch_validate_envelope(root,"GetSeries")
    series=ubcch_json_get(root,"Series")
    if (series==NULL | ubcch_json_kind(series)!=5) {
        errprintf("usebcch: respuesta GetSeries sin objeto Series\n")
        exit(610)
    }
    ubcch_require_string(series,"seriesId","GetSeries")
    ubcch_require_string(series,"descripEsp","GetSeries")
    ubcch_require_string(series,"descripIng","GetSeries")
    observations=ubcch_required_member(series,"Obs",4,"GetSeries")
    for (i=1; i<=ubcch_json_size(observations); i++) {
        observation=ubcch_json_item(observations,i)
        if (observation==NULL) {
            errprintf("usebcch: malformed GetSeries response (invalid observation)\n")
            exit(610)
        }
        if (ubcch_json_kind(observation)!=5) {
            errprintf("usebcch: malformed GetSeries response (invalid observation)\n")
            exit(610)
        }
        ubcch_require_string(observation,"indexDateString","GetSeries")
        ubcch_require_string(observation,"value","GetSeries")
        ubcch_require_string(observation,"statusCode","GetSeries")
    }
    item=ubcch_json_get(series,"seriesId")
    id=item==NULL ? "" : ubcch_json_string(item)
    item=ubcch_json_get(series,"descripEsp")
    title_es=item==NULL ? "" : ubcch_json_string(item)
    item=ubcch_json_get(series,"descripIng")
    title_en=item==NULL ? "" : ubcch_json_string(item)
    st_local("_ub_title_es",title_es)
    st_local("_ub_title_en",title_en)
    obs=ubcch_json_obs(root,("indexDateString","value","statusCode"))
    n=rows(obs)
    if (!n) return
    firstobs=st_nobs()+1
    st_addobs(n)
    dates=J(n,1,.)
    values=J(n,1,.)
    for (i=1; i<=n; i++) {
        dates[i]=ubcch_daily(obs[i,1])
        values[i]=strtoreal(obs[i,2])
    }
    st_store((firstobs::firstobs+n-1),"time",dates)
    st_store((firstobs::firstobs+n-1),"value",values)
    st_sstore((firstobs::firstobs+n-1),"series_id",J(n,1,id))
    st_sstore((firstobs::firstobs+n-1),"spanish_name",J(n,1,title_es))
    st_sstore((firstobs::firstobs+n-1),"english_name",J(n,1,title_en))
    st_sstore((firstobs::firstobs+n-1),"status",obs[,3])
    st_sstore((firstobs::firstobs+n-1),"value_raw",obs[,2])
}

void ubcch_import_search(string scalar filename)
{
    pointer(struct ubcch_json_value scalar) scalar root, infos, info, item
    string matrix table
    string scalar description
    real matrix dates
    real scalar i, j, n, firstobs, code
    string rowvector fields

    fields=("seriesId","frequencyCode","spanishTitle","englishTitle",
            "firstObservation","lastObservation","updatedAt","createdAt")
    root=ubcch_parse_file(filename)
    ubcch_validate_envelope(root,"SearchSeries")
    item=ubcch_json_get(root,"Codigo")
    code=ubcch_json_number(item)
    item=ubcch_json_get(root,"Descripcion")
    description=ubcch_json_string(item)
    st_local("_ub_code",strofreal(code,"%18.0g"))
    st_local("_ub_desc",description)
    st_local("_ub_operation","search")
    if (code!=0) return
    infos=ubcch_json_get(root,"SeriesInfos")
    for (i=1; i<=ubcch_json_size(infos); i++) {
        info=ubcch_json_item(infos,i)
        if (info==NULL) {
            errprintf("usebcch: malformed SearchSeries response (invalid catalog entry)\n")
            exit(610)
        }
        if (ubcch_json_kind(info)!=5) {
            errprintf("usebcch: malformed SearchSeries response (invalid catalog entry)\n")
            exit(610)
        }
        for (j=1; j<=cols(fields); j++)
            ubcch_require_string(info,fields[j],"SearchSeries")
    }
    table=ubcch_json_seriesinfos(root,fields)
    n=rows(table)
    if (!n) return
    firstobs=st_nobs()+1
    st_addobs(n)
    st_sstore((firstobs::firstobs+n-1),"series_id",table[,1])
    st_sstore((firstobs::firstobs+n-1),"frequency",table[,2])
    st_sstore((firstobs::firstobs+n-1),"spanish_title",table[,3])
    st_sstore((firstobs::firstobs+n-1),"english_title",table[,4])
    dates=J(n,4,.)
    for (i=1; i<=n; i++) {
        dates[i,1]=ubcch_daily(table[i,5])
        dates[i,2]=ubcch_daily(table[i,6])
        dates[i,3]=ubcch_daily(table[i,7])
        dates[i,4]=ubcch_daily(table[i,8])
    }
    st_store((firstobs::firstobs+n-1),
             ("first_observation","last_observation","updated_at","created_at"),dates)
}

end
