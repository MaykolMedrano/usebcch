/*
    usebcch_json.mata -- small, dependency-free JSON parser for usebcch

    Public API
    ----------
    pointer scalar ubcch_json_parse(string scalar json)
        Parse JSON and return a pointer to the root ubcch_json_value.
        Syntax errors abort with error 610 and an offset in the input.

    real scalar   ubcch_json_kind(pointer scalar p)
    string scalar ubcch_json_string(pointer scalar p)
    real scalar   ubcch_json_number(pointer scalar p)
    real scalar   ubcch_json_boolean(pointer scalar p)
    real scalar   ubcch_json_isnull(pointer scalar p)
    real scalar   ubcch_json_size(pointer scalar p)
    pointer scalar ubcch_json_item(pointer scalar p, real scalar i)
    pointer scalar ubcch_json_get(pointer scalar p, string scalar key)
    pointer scalar ubcch_json_path(pointer scalar p, string scalar path)
        Object navigation; path components are separated by dots.

    pointer scalar ubcch_json_find(pointer scalar p, string scalar key)
        Recursively find the first value belonging to key (case-sensitive).

    string matrix ubcch_json_table(pointer scalar p, string scalar arraykey,
                                    string rowvector fields)
        Find an array recursively and return its object elements as strings.
        Nested fields may use dotted paths. JSON null becomes "".

    Convenience wrappers for the two BCCh endpoints:
        ubcch_json_series(p, fields)       // array named "Series"
        ubcch_json_obs(p, fields)          // array named "Obs"
        ubcch_json_seriesinfos(p, fields)  // array named "SeriesInfos"

    Kind constants returned by ubcch_json_kind():
        0 null, 1 boolean, 2 number, 3 string, 4 array, 5 object.

    This file intentionally has no dependency on Stata's Python integration.
*/

mata:

struct ubcch_json_value {
    real scalar kind
    real scalar number
    string scalar text
    string rowvector keys
    pointer(struct ubcch_json_value scalar) rowvector values
}

struct ubcch_json_parser {
    string scalar source
    real scalar position
    real scalar length
}

void ubcch_json_fail(struct ubcch_json_parser scalar P, string scalar message)
{
    errprintf("usebcch: invalid JSON at character %g: %s\n", P.position, message)
    exit(610)
}

void ubcch_json_space(struct ubcch_json_parser scalar P)
{
    string scalar c
    while (P.position <= P.length) {
        c = substr(P.source, P.position, 1)
        if (c!=" " & c!=char(9) & c!=char(10) & c!=char(13)) return
        P.position=P.position+1
    }
}

real scalar ubcch_json_hex4(struct ubcch_json_parser scalar P)
{
    real scalar i, d, value
    string scalar c
    if (P.position+3 > P.length) ubcch_json_fail(P, "incomplete Unicode escape")
    value = 0
    for (i=0; i<4; i++) {
        c = substr(P.source, P.position+i, 1)
        d = strpos("0123456789abcdef", strlower(c))-1
        if (d < 0) ubcch_json_fail(P, "invalid Unicode escape")
        value = 16*value+d
    }
    P.position = P.position+4
    return(value)
}

string scalar ubcch_json_qstring(struct ubcch_json_parser scalar P)
{
    string scalar out, c, e
    real scalar u, low
    if (substr(P.source,P.position,1)!=char(34)) ubcch_json_fail(P, "string expected")
    P.position=P.position+1
    out = ""
    while (P.position <= P.length) {
        c = substr(P.source,P.position,1)
        P.position=P.position+1
        if (c==char(34)) return(out)
        if (strlen(c)==1) {
            if (ascii(c)<32) ubcch_json_fail(P, "unescaped control character in string")
        }
        if (c!=char(92)) {
            out = out+c
            continue
        }
        if (P.position>P.length) ubcch_json_fail(P, "incomplete string escape")
        e = substr(P.source,P.position,1)
        P.position=P.position+1
        if (e==char(34) | e==char(92) | e=="/") out=out+e
        else if (e=="b") out=out+char(8)
        else if (e=="f") out=out+char(12)
        else if (e=="n") out=out+char(10)
        else if (e=="r") out=out+char(13)
        else if (e=="t") out=out+char(9)
        else if (e=="u") {
            u=ubcch_json_hex4(P)
            if (u>=55296 & u<=56319) {
                if (substr(P.source,P.position,2)!="\u")
                    ubcch_json_fail(P, "high surrogate without low surrogate")
                P.position=P.position+2
                low=ubcch_json_hex4(P)
                if (low<56320 | low>57343)
                    ubcch_json_fail(P, "invalid low surrogate")
                u=65536+(u-55296)*1024+(low-56320)
            }
            else if (u>=56320 & u<=57343)
                ubcch_json_fail(P, "unexpected low surrogate")
            out=out+uchar(u)
        }
        else ubcch_json_fail(P, "unknown string escape")
    }
    ubcch_json_fail(P, "unterminated string")
    return("")
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_value_parse(
    struct ubcch_json_parser scalar P, real scalar depth)
{
    struct ubcch_json_value scalar V
    string scalar c, token, key
    real scalar start, count, capacity, i
    pointer(struct ubcch_json_value scalar) scalar child
    pointer(struct ubcch_json_value scalar) rowvector buffer

    if (depth>512) ubcch_json_fail(P,"maximum nesting depth exceeded")
    V.kind=0
    V.number=.
    V.text=""
    V.keys=J(1,0,"")
    V.values=J(1,0,NULL)
    ubcch_json_space(P)
    if (P.position>P.length) ubcch_json_fail(P,"value expected")
    c=substr(P.source,P.position,1)

    if (c==char(34)) {
        V.kind=3
        V.text=ubcch_json_qstring(P)
        return(&V)
    }
    if (c=="[") {
        V.kind=4
        P.position=P.position+1
        ubcch_json_space(P)
        if (substr(P.source,P.position,1)=="]") {
            P.position=P.position+1
            return(&V)
        }
        count=0
        capacity=16
        buffer=J(1,capacity,NULL)
        while (1) {
            child=ubcch_json_value_parse(P,depth+1)
            count=count+1
            if (count>capacity) {
                buffer=buffer,J(1,capacity,NULL)
                capacity=2*capacity
            }
            buffer[count]=child
            ubcch_json_space(P)
            c=substr(P.source,P.position,1)
            if (c=="]") {
                P.position=P.position+1
                V.values=buffer[|1\count|]
                return(&V)
            }
            if (c!=",") ubcch_json_fail(P,"comma or closing bracket expected")
            P.position=P.position+1
        }
    }
    if (c=="{") {
        V.kind=5
        P.position=P.position+1
        ubcch_json_space(P)
        if (substr(P.source,P.position,1)=="}") {
            P.position=P.position+1
            return(&V)
        }
        while (1) {
            ubcch_json_space(P); key=ubcch_json_qstring(P); ubcch_json_space(P)
            for (i=1; i<=cols(V.keys); i++) {
                if (V.keys[i]==key) ubcch_json_fail(P,"duplicate object key")
            }
            if (substr(P.source,P.position,1)!=":") ubcch_json_fail(P,"colon expected")
            P.position=P.position+1
            child=ubcch_json_value_parse(P,depth+1)
            V.keys=V.keys,key
            V.values=V.values,child
            ubcch_json_space(P)
            c=substr(P.source,P.position,1)
            if (c=="}") {
                P.position=P.position+1
                return(&V)
            }
            if (c!=",") ubcch_json_fail(P,"comma or closing brace expected")
            P.position=P.position+1
        }
    }
    if (substr(P.source,P.position,4)=="null") {
        V.kind=0
        P.position=P.position+4
        return(&V)
    }
    if (substr(P.source,P.position,4)=="true") {
        V.kind=1
        V.number=1
        P.position=P.position+4
        return(&V)
    }
    if (substr(P.source,P.position,5)=="false") {
        V.kind=1
        V.number=0
        P.position=P.position+5
        return(&V)
    }
    start=P.position
    while (P.position<=P.length & strpos("-+0123456789.eE",substr(P.source,P.position,1)))
        P.position=P.position+1
    token=substr(P.source,start,P.position-start)
    if (!ustrregexm(token,"^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$"))
        ubcch_json_fail(P,"invalid value or number")
    V.kind=2
    V.number=strtoreal(token)
    V.text=token
    return(&V)
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_parse(string scalar json)
{
    struct ubcch_json_parser scalar P
    pointer(struct ubcch_json_value scalar) scalar root
    P.source=json; P.position=1; P.length=strlen(json)
    if (ustrinvalidcnt(json)) ubcch_json_fail(P,"invalid UTF-8")
    root=ubcch_json_value_parse(P,0)
    ubcch_json_space(P)
    if (P.position<=P.length) ubcch_json_fail(P,"data after root value")
    return(root)
}

real scalar ubcch_json_kind(pointer(struct ubcch_json_value scalar) scalar p)
{
    return((*p).kind)
}

real scalar ubcch_json_number(pointer(struct ubcch_json_value scalar) scalar p)
{
    return((*p).number)
}

real scalar ubcch_json_boolean(pointer(struct ubcch_json_value scalar) scalar p)
{
    return((*p).kind==1 ? (*p).number : .)
}

real scalar ubcch_json_isnull(pointer(struct ubcch_json_value scalar) scalar p)
{
    return((*p).kind==0)
}

real scalar ubcch_json_size(pointer(struct ubcch_json_value scalar) scalar p)
{
    return(cols((*p).values))
}

string scalar ubcch_json_string(pointer(struct ubcch_json_value scalar) scalar p)
{
    if ((*p).kind==3 | (*p).kind==2) return((*p).text)
    if ((*p).kind==1) return((*p).number ? "true" : "false")
    if ((*p).kind==0) return("")
    return("")
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_item(pointer(struct ubcch_json_value scalar) scalar p, real scalar i)
{
    if ((*p).kind!=4 | i<1 | i>cols((*p).values)) return(NULL)
    return((*p).values[i])
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_get(pointer(struct ubcch_json_value scalar) scalar p, string scalar key)
{
    real scalar i
    if (p==NULL) return(NULL)
    if ((*p).kind!=5) return(NULL)
    for (i=1; i<=cols((*p).keys); i++) if ((*p).keys[i]==key) return((*p).values[i])
    return(NULL)
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_path(pointer(struct ubcch_json_value scalar) scalar p, string scalar path)
{
    string rowvector parts
    real scalar i
    pointer(struct ubcch_json_value scalar) scalar q
    parts=tokens(path,".")
    q=p
    for (i=1; i<=cols(parts); i++) {
        q=ubcch_json_get(q,parts[i])
        if (q==NULL) return(NULL)
    }
    return(q)
}

pointer(struct ubcch_json_value scalar) scalar ubcch_json_find(pointer(struct ubcch_json_value scalar) scalar p, string scalar key)
{
    real scalar i
    pointer(struct ubcch_json_value scalar) scalar q
    if (p==NULL) return(NULL)
    if ((*p).kind==5) {
        q=ubcch_json_get(p,key)
        if (q!=NULL) return(q)
    }
    if ((*p).kind==4 | (*p).kind==5) {
        for (i=1; i<=cols((*p).values); i++) {
            q=ubcch_json_find((*p).values[i],key)
            if (q!=NULL) return(q)
        }
    }
    return(NULL)
}

string matrix ubcch_json_table(pointer(struct ubcch_json_value scalar) scalar p, string scalar arraykey,
                               string rowvector fields)
{
    pointer(struct ubcch_json_value scalar) scalar a, row, cell
    string matrix out
    real scalar i, j
    a=ubcch_json_find(p,arraykey)
    if (a==NULL) return(J(0,cols(fields),""))
    if ((*a).kind!=4 & (*a).kind!=5) return(J(0,cols(fields),""))
    if ((*a).kind==5) {
        out=J(1,cols(fields),"")
        for (j=1; j<=cols(fields); j++) {
            cell=ubcch_json_path(a,fields[j])
            if (cell!=NULL) out[1,j]=ubcch_json_string(cell)
        }
        return(out)
    }
    out=J(cols((*a).values),cols(fields),"")
    for (i=1; i<=cols((*a).values); i++) {
        row=(*a).values[i]
        for (j=1; j<=cols(fields); j++) {
            cell=ubcch_json_path(row,fields[j])
            if (cell!=NULL) out[i,j]=ubcch_json_string(cell)
        }
    }
    return(out)
}

string matrix ubcch_json_series(pointer(struct ubcch_json_value scalar) scalar p, string rowvector fields)
{
    return(ubcch_json_table(p,"Series",fields))
}

string matrix ubcch_json_obs(pointer(struct ubcch_json_value scalar) scalar p, string rowvector fields)
{
    return(ubcch_json_table(p,"Obs",fields))
}

string matrix ubcch_json_seriesinfos(pointer(struct ubcch_json_value scalar) scalar p, string rowvector fields)
{
    return(ubcch_json_table(p,"SeriesInfos",fields))
}

end
