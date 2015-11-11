md5 = require("js-md5")

TABLES =
  gender:
    F: "female"
    M: "male"
    N: "other"
    U: "unknown"
    O: "other"
    A: "unknown"
    undefined: "unknown"

  maritalStatus:
    # P - polygamous
    # W - widowed
    N: "A"
    C: ""
    D: "D"
    P: ""
    I: "I"
    E: "L"
    G: ""
    M: "M"
    O: ""
    R: "T"
    A: ""
    S: "S"
    U: "UNK"
    B: "U"
    T: "UNK"

isBlank = (val) ->
  val == null ||
    val == undefined ||
    val == '' ||
    (Array.isArray(val) && val.length == 0)

getIn = (obj, path) ->
  result = obj

  path.split(".").forEach (x) ->
    if !(result == null or result == undefined)
      result = result[x]

  return result

module.exports =
  helpers:
    capitalize: (s) ->
      return null if !s
      s[0].toUpperCase() + s.substr(1).toLowerCase()

    debug: (v) ->
      JSON.stringify(v)

    md5: (v) ->
      md5(JSON.stringify(v))

    compact: (v) ->
      if Array.isArray(v)
        result = []
        for i in v
          result.push(i) if !isBlank(i)

        result
      else
        if isBlank(v) then null else v

    toBool: (v) ->
      if v == 'N' || !v then false else true

    flatten: (v) ->
      return v if !Array.isArray(v)

      result = []
      for item in v
        if Array.isArray(item)
          result = result.concat(item)
        else
          result.push(item)

      result

    join: (v, s) ->
      return v if !Array.isArray(v)
      v.join(s)

    split: (v, s) ->
      return v if typeof(v) != "string"
      v.split(s)

    uniq: (v, attr) ->
      return v if !Array.isArray(v)
      result = []
      index = {}

      for item in v
        attrValue = getIn(item, attr)
        if !index[String(attrValue)]
          result.push(item)
          index[String(attrValue)] = true

      result

    dateTime: (str) ->
      if !str || typeof(str) != 'string'
        # throw "Argument to dateTime() filter must be a string"
        return null

      year = str[0..3]
      month = str[4..5]
      day = str[6..7]
      hour = str[8..9]
      minute = str[10..11]
      second = str[12..13]

      new Date(year, month, day, hour, minute, second)

    translateCode: (v, tableName) ->
      tbl = TABLES[tableName]

      if !tbl
        throw "Unknown codes mapping table: #{tableName}"

      if tbl[v]
        tbl[v]
      else if tbl['$default']
        tbl['$default']
      else
        throw "Code '#{v}' is not found in mapping table #{tableName}"

    str: (v) ->
      String(v)

    trim: (v) ->
      return v if typeof(v) != 'string'
      v.trim()

    identity: (v) ->
      return v

    json: (v, pretty) ->
      if pretty
        JSON.stringify(v, null, 1)
      else
        JSON.stringify(v)
