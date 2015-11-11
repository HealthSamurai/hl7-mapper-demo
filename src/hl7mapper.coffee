traverse = require('traverse')
parser = require('./parser')
helpers = require('./helpers')

HELPERS = helpers.helpers

clone = (obj) ->
  JSON.parse(JSON.stringify(obj))

getIn = (obj, path, needLeaf) ->
  result = obj

  path.forEach (x) ->
    if !(result == null or result == undefined)
      getFirst = false

      if x[x.length - 1] == '~'
        x = x.substr(0, x.length - 1)
        getFirst = true

      result = result[x]

      if getFirst && Array.isArray(result) && result[0] == '&'
        result = result[1]

  if needLeaf && Array.isArray(result) && result.length == 2 && result[0] == '^'
    result[1]
  else
    result

updateIn = (obj, path, newValue) ->
  object = obj

  while path.length > 1
    object = object[path.shift()]

  object[path.shift()] = newValue

assignHl7Path = (n, path) ->
  if n != null && n != undefined
    p = path.join(".")

    switch typeof(n)
      when 'object'
        n.path = p
      when 'string'
        n
      when 'number'
        n = new Number(n)
        n.path = p
      when 'boolean'
        n = new Boolean(n)
        n.path = p
  n

assignHl7Paths = (segName, seg) ->
  assignHl7Path(seg, [segName])

  for fieldIdx, field of seg when fieldIdx != 'path'
    if fieldIdx.match(/^\d+$/)
      assignHl7Path(field, [segName, fieldIdx])
    else
      if Array.isArray(field)
        for subSegIdx, subSeg of field
          subSeg = assignHl7Paths(fieldIdx, subSeg)
      else
        subSeg = assignHl7Paths(fieldIdx, field)

  seg

parsePath = (p) ->
  p.split('.').map (e) -> e.trim()

# This is a quick & dirty implementation
# of expression evaluator. More robust approach
# is to write a parser and to implement
# an interpreter, but it's too much work for now.
evalExpression = (expr, context) ->
  pathRegexp = /"(?:[^"\\]|\\.)*"|([a-zA-Z_0-9~][a-zA-Z_0-9.~]+[a-zA-Z_0-9~])/g
  filterRegexp = /(\s*\|\s*[a-zA-Z0-9_]+(\([^)]+\))?)*\s*$/
  filters = null

  # get filters at first
  e = String(expr).replace filterRegexp, (f_str) ->
    filters = f_str.split(/\s*\|\s*/).map (f) ->
      f = f.trim()

      if f.indexOf("(") > 0
        args = f.match(/\(([^)]+)\)$/)[1].split(",").map(JSON.parse)
        f = f.substr(0, f.indexOf("("))
        [f, args]
      else
        f

    filters.shift()
    ""

  e = e.replace pathRegexp, (fullMatch, pathStr) ->
    if pathStr
      path = parsePath(pathStr)
      "getIn(context, #{JSON.stringify(path)}, true)"
    else
      fullMatch

  # console.log "!!!!! =>", e
  result = eval(e)

  for filter in filters
    if Array.isArray(filter)
      name = filter.shift()
      args = filter
    else
      name = filter
      args = []

    filterFn = HELPERS[name]

    if !filterFn
      throw "Unknown filter: '#{name}'"

    result = filterFn.apply(context, [result].concat(args))

  result

isSpecialNode = (node) ->
  isObject = node != null and
    node != undefined and
    typeof node == 'object'

  if isObject
    containsDollarKeys = false
    containsDollarKeys = true for k of node when k.match(/^\$/)
    containsDollarKeys

isInterpolableString = (node) ->
  node != null and
    node != undefined and
    typeof node == 'string' and
    (node.indexOf('{{') >= 0 || node[0] == '$')

resultToString = (result) ->
  if result == null || result == undefined
    ""
  else
    String(result)

interpolateString = (str, context) ->
  if str.trim()[0] == '$'
    expr = str.match(/^\$(.+)$/)[1]
    evalExpression(expr, context)
  else
    str.replace /\{\{([^}]+)\}\}/g, (m, expr) ->
      resultToString(evalExpression(expr, context))

nodeValue = (node) ->
  v = null

  if node.$value
    v = clone(node.$value, false, 1)
  else
    v = clone(node, false, 1)

  v

evalForeach = (node, context) ->
  if node && node.$foreach
    expr = node.$foreach
    components = expr.split(' as ').map (str) ->
      str.trim()

    paths = components[0].split(",").map(parsePath)
    varName = components[1]

    array = paths.reduce((acc, p) ->
      v = getIn(context, p, false)
      if v && (!Array.isArray(v) || v[0] == '^')
        v = [ v ]

      acc.concat(v)
    , [])

    value = nodeValue(node)

    if value.$foreach
      delete value.$foreach

    result = []

    array.forEach (e) ->
      newContext = {}
      newContext.__proto__ = context
      newContext[varName] = e

      result.push evalNode(value, newContext)
      return

    result
  else
    node

evalJs = (node, context) ->
  if node && node.$js
    eval(node.$js)
  else
    node

evalFilter = (node, context) ->
  if node && node.$filter
    filter = node.$filter
    val = nodeValue(node)
    delete val['$filter']

    val = evalNode(val, context)

    applyFilter = (filterName, val) ->
      if filterName.indexOf('(') > 0
        filterArgs = filterName.match(/\(([^)]+)\)$/)[1].split(",").map(JSON.parse)
        filterName = filterName.substr(0, filterName.indexOf("("))
      else
        filterArgs = []

      filterFn = HELPERS[filterName]

      if !filterFn
        throw "Unknown filter: '#{filterName}'"

      filterFn.apply(context, [val].concat(filterArgs))


    if Array.isArray(filter)
      result = val

      for f in filter
        result = applyFilter(f, result)

      result
    else
      applyFilter(filter, val)
  else
    node

evalCase = (node, context) ->
  if node && node.$case
    expr = node.$case
    evalResult = evalExpression(expr, context)

    resultNode = clone(node[evalResult])

    if !resultNode
      resultNode = clone(node['$default'])

    resultNode
  else
    node

evalLet = (node, context) ->
  if node && node.$let
    childContext = {}
    childContext.__proto__ = context

    for k, expr of node.$let
      childContext[k] = evalSingleNode(expr, childContext)

    value = nodeValue(node)
    delete value.$let

    evalNode(value, childContext)
  else
    node

evalIf = (node, context) ->
  if node && node.$if
    expr = node.$if
    evalResult = evalExpression(expr, context)

    if evalResult
      result = nodeValue(node)
      delete result['$if']
      evalNode(result, context)
    else
      result = node['$else'] || {}
      evalNode(result, context)
  else
    node

evalExpr = (node, context) ->
  if node && node.$expr
    expr = node.$expr
    evalExpression(expr, context)
  else
    node

evalImport = (node, context) ->
  if node && node.$import
    fileName = node.$import
    mapping = readMapping(fileName)

    if !mapping
      throw "Cannot find mapping named '#{fileName}' among mapping paths"

    evalNode(mapping, context)
  else
    node

evalSpecialNode = (node, context) ->
  result = node
  result = evalLet(result, context)
  result = evalIf(result, context)
  result = evalCase(result, context)
  result = evalFilter(result, context)
  result = evalForeach(result, context)
  result = evalJs(result, context)
  result = evalImport(result, context)
  result = evalExpr(result, context)

  result


evalSingleNode = (node, context) ->
  result = node

  if isSpecialNode(node)
    result = evalSpecialNode(node, context)
  else if isInterpolableString(node)
    result = interpolateString(node, context)
  result

evalRootNode = (node, context) ->
  rootKeys = ['$maintainer', '$description', '$structure']
  result = clone(node, false, 1)

  for k, v of result
    if rootKeys.indexOf(k) >= 0
      delete result[k]

  evalNode(result, context)

evalNode = (mapping, context) ->
  newMapping = evalSingleNode(clone(mapping), context)

  traverse(newMapping).forEach (x) ->
    @update evalSingleNode(x, context)
    return

  newMapping

isBlank = (val) ->
  val == null ||
    val == undefined ||
    val == '' ||
    (Array.isArray(val) && val.length == 0)

# We need to perform a depth-first
# traverse of a tree, so js-traverse package
# is not suitable for such purpose.
removeBlanks = (rootNode) ->
  if typeof(rootNode) == 'object'
    if Array.isArray(rootNode)
      # we've got an array, yay!
      newNode = rootNode.map (e) ->
        removeBlanks(e)

      newNode = newNode.filter (e) ->
        !isBlank(e)

      if isBlank(newNode)
        null
      else
        newNode
    else if rootNode instanceof Date
      rootNode
    else
      # wow, it's an object!
      newNode = {}
      atLeastOneKey = false

      for k, v of rootNode
        newV = removeBlanks(v)

        if !isBlank(newV)
          atLeastOneKey = true
          newNode[k] = newV

      if atLeastOneKey
        newNode
      else
        null
  else
    # string, number, bool
    if isBlank(rootNode)
      null
    else
      if typeof(rootNode) == 'string'
        trimmed = rootNode.trim()
        if isBlank(trimmed)
          null
        else
          trimmed
      else
        rootNode

doMapping = (msg_string, mapping) ->
  msg = parser.parse(msg_string)

  # replace blanks with null
  traverse(msg).forEach (x) ->
    if typeof x == 'string' and x.trim() == ''
      @update null

  structure = mapping.$structure

  if !structure
    throw "No $structure attribute in mapping's root node"

  msg = parser.nest(structure, msg, false)

  # assign .path attrubute to each field
  for segName, segs of msg
    if Array.isArray(segs)
      for seg in segs
        seg = assignHl7Paths(segName, seg)
    else
      segs = assignHl7Paths(segName, segs)

  mapped = evalRootNode(mapping, msg)
  # prom = resolvePromises(mapped)
  # prom.then (value) ->
  #   removeBlanks(value)
  removeBlanks(mapped)

module.exports =
  doMapping: doMapping
