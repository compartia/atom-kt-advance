module.exports = Htmler =

    rangeToHtml:(range) ->
        if range?
            return 'line:'+(range.start.row)+' col:'+range.start.column
        else
            return '-'

    wrapAttr: (attr, val) -> attr + '="' + val + '"'+' '

    wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = '' 

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'
