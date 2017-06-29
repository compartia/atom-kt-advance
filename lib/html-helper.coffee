module.exports = Htmler =


    rangeToHtml:(range) ->
        'line:'+(range[0][0])+' col:'+range[0][1]

    wrapAttr: (attr, val) -> attr + '="' + val + '"'+' '

    wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = '' 

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'
