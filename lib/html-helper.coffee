module.exports = Htmler =


    rangeToHtml:(range) ->
        'line:'+(range.start.row+1)+' col:'+range.start.column

    wrapAttr: (attr, val) -> attr + '="' + val + '"'+' '

    wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = ''

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'
