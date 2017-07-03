module.exports = Htmler =


    # rangeToHtml:(range) ->
    #     'line:'+(range[0][0])+' col:'+range[0][1]
    
    rangeToHtml:(range) ->
        if range?
            if range.start?
                return 'line:'+(range.start.row)+' col:'+range.start.column
            
            if range.length
                return 'line:'+(range[0][0])+' col:'+range[0][1]
        return ''

    wrapAttr: (attr, val) -> attr + '="' + val + '"'+' '

    wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = '' 

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'
