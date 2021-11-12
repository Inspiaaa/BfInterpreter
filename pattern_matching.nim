
import macros


proc isNodeWildcard(node: NimNode): bool =
    node.kind == nnkIdent and eqIdent(node, "_")


proc isNodeOr(node: NimNode): bool =
    node.kind == nnkInfix and eqIdent(node[0], "or")


proc flattenOrHierarchy(node: NimNode): seq[NimNode] =
    ## Flattens a nested logic hierarchy of ORs into a sequence of elements.
    ##
    ## Example:
    ## a or b or c
    ## => @[a, b, c]

    # Left and right nodes of the OR expression
    var expressionsToCheck = @[node[1], node[2]]
    while len(expressionsToCheck) > 0:
        let expression = expressionsToCheck.pop()

        if isNodeOr(expression):
            expressionsToCheck.add(expression[1])
            expressionsToCheck.add(expression[2])
        else:
            result.add(expression)


macro matchPattern*(data: untyped, tokens: varargs[untyped], offset: static[int] = 0): untyped =
    ## Lets you write generic pattern matching code for types that can be indexed with [].
    ##
    ## Example:
    ## let s = @[1, 2, 3, 4, 5]
    ## echo matchPattern(s, 1, 2, _, 0 or 4)  # Output: true
    ## Same as: s[0] == 1 and s[1] == 2 and (s[3] == 0 or s[4] == 5)
    ##
    ## Literal: any type or expression
    ## Wildcards: _
    ## Multiple options for one index: a or b (or c or d or ...)

    template makePatternCheck(idx: int, token: untyped): untyped =
        infix(newCall("[]", data, newIntLitNode(idx)), "==", token)

    template makeOr(left, right: NimNode): NimNode =
        infix(left, "or", right)

    template makeAnd(left, right: NimNode): NimNode =
        infix(left, "and", right)

    var expression: NimNode = ident("true")

    var idx = offset
    for token in tokens:
        # Arguments with _ are wildcards
        if isNodeWildcard(token):
            discard

        # If you enter (a or b (or c or d...)) as a parameter, they all get checked for that index.
        elif isNodeOr(token):
            var possiblePatterns = flattenOrHierarchy(token)
            var multipleOptionMatcher = makeOr(
                makePatternCheck(idx, possiblePatterns[0]),
                makePatternCheck(idx, possiblePatterns[1])
            )

            for pattern in possiblePatterns[2..^1]:
                multipleOptionMatcher = makeOr(
                    multipleOptionMatcher,
                    makePatternCheck(idx, token)
                )

            expression = makeAnd(expression, multipleOptionMatcher)

        else:
            expression = makeAnd(expression, makePatternCheck(idx, token))

        inc idx

    # echo treeRepr(expression)
    return expression
