_parseMsh = (msg) ->
  msh = msg.substr(0, msg.indexOf("\n"))
  msh.split("|").map (f, i) ->
    f.split("&")

_parse = (m) ->
  msg = m.trim().split("\n").map (s) ->
    s.split("|").map (f, i) ->
      if f.indexOf("&") >= 0
        ["&"].concat f.split("&").map (c) ->
          ["^"].concat c.split("^")
      else
        if i != 0 then ["^"].concat f.split("^") else f

  for seg, i in msg
    segObj = {}

    for field, fieldIdx in seg
      segObj[fieldIdx] = field

    msg[i] = segObj

  msg

_doNest = (struct, msg, strict) ->
  fullStruct = [
    '',
    'ROOT',
    ['', "MSH"],
    ['?', "EVN"]
  ].concat(struct)

  result = {}
  [success, finalIndex, errorMsg] = _nest(fullStruct, msg, 0, result)

  # console.log "!!!!!", errorMsg, success, finalIndex

  if finalIndex < msg.length && strict
    unnestedSegments = []
    for s, i in msg when i >= finalIndex
      unnestedSegments.push(s[0])

    throw "There are discarded segments in message starting from position #{finalIndex}: #{unnestedSegments.join(', ')}"

  if success
    result["ROOT"]
  else
    throw errorMsg

_nest = (struct, msg, msgIndex, resultRef) ->

  thisSegName = struct[1]
  thisSegOpts = struct[0]
  childSegs = struct[2..-1]
  isOptional = thisSegOpts.indexOf("?") >= 0

  if !msg[msgIndex]
    if !isOptional
      return [false, msgIndex, "Expecting segment #{thisSegName} at position #{msgIndex}"]
    else
      return [true, msgIndex, null]

  currSeg = msg[msgIndex]
  currSegName = currSeg[0]

  newResultRef = null

  # console.log("!!!!", "msg seg:", currSegName, "struct seg:", thisSegName, "current result:", resultRef)

  rootCase = false
  subResult = null
  subResultRef = null

  if msgIndex == 0 && thisSegName == 'ROOT'
    # special case for root struct node
    rootCase = true
    subResult = {}
    subResultRef = subResult
  else
    subResult = currSeg
    subResultRef = subResult

  if thisSegName == currSegName || rootCase
    repeatable = thisSegOpts.indexOf('*') >= 0

    if repeatable
      # console.log "!!!! REPEATABLE!"
      subResult = [currSeg]
      subResultRef = subResult[0]

    allChildrenNested = true
    currMsgIndex = if rootCase then msgIndex else msgIndex + 1
    prevMsgIndex = msgIndex
    childError = null
    # console.log "!!!!", "nesting children of", thisSegName

    while true
      for seg, segIdx in childSegs
        [childNested, currMsgIndex, childError] = _nest(seg, msg, currMsgIndex, subResultRef)
        allChildrenNested = allChildrenNested && childNested
        # console.log "nested child", seg[1], "=>", childNested, "msg index:", currMsgIndex, "err: ", childError

        break if !childNested

      break unless repeatable &&
                   msg[currMsgIndex] &&
                   msg[currMsgIndex][0] == thisSegName &&
                   prevMsgIndex < currMsgIndex

      # console.log "!!! repeating again!", msg[currMsgIndex][0], thisSegName, prevMsgIndex, currMsgIndex

      # now we're looking at the next repeatable segment,
      # so add it to subResult

      subResult.push(msg[currMsgIndex])
      subResultRef = subResult[subResult.length - 1]
      prevMsgIndex = currMsgIndex
      currMsgIndex += 1 # moving to next segment

    if allChildrenNested
      resultRef[thisSegName] = subResult

      return [true, currMsgIndex, null]
    else
      return [false, msgIndex, childError]

  else
    if !isOptional
      return [false, msgIndex, "Expecting segment #{thisSegName}, got #{currSegName} at position #{msgIndex}"]
    else
      return [true, msgIndex, null]

module.exports =
  parse: _parse
  nest: _doNest
  parseMsh: _parseMsh
