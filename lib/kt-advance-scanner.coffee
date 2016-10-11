KT_JSON_DIR='kt_analysis_export'

{File} = require 'atom'
fs = require 'fs'
path = require 'path'

KtAdvanceJarExecutor = require './jar-exec'
KtAdvanceColorLayer = require './links-layer'


class KtAdvanceScanner

    grammarScopes: ['source.c']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    linter: null
    executor: null



    constructor: () ->
        @_log 'contructor'
        @executor=new KtAdvanceJarExecutor()
        @layersByEditorId=[]


    setLinter: (_linter) ->
        @linter=_linter

    mayBeExecJar: (jsonFile) ->
        @_log 'mayBeExecJar'
        #if not jsonFile.existsSync()
        #    @execJar()


    getJsonPath:(textEditor) ->
        filePath = textEditor.getPath()
        rootDir = @executor.findRoot(filePath)
        # @_log 'rootDir:', rootDir
        relative = path.relative(rootDir, filePath)
        # @_log 'relative path:', relative
        file = path.join rootDir, KT_JSON_DIR, (relative + '.json')
        # @_log 'json path:', file
        return file

    getOrMakeMarkersLayer: (textEditor)->
        @_log 'creating marker layer for editor id '+ textEditor.id, '....'
        if not @layersByEditorId[textEditor.id]?
            @layersByEditorId[textEditor.id] = new KtAdvanceColorLayer(textEditor)
            @_log 'created marker layer for editor id '+ textEditor.id
        return @layersByEditorId[textEditor.id]



    scan: (textEditor) ->
        messages = @lint(textEditor)

        Promise.resolve(messages).then (value) =>
            @submitMessages(value)


    submitMessages:(messages)->
        @_log 'messages:', messages.length
        if messages.length is 0
            @linter?.deleteMessages()
            return
        @linter?.setMessages(messages)

    accept: (filePath) ->
        return path.extname(filePath) == '.c'

    ## @Overrides
    lint: (textEditor) =>
        filePath = textEditor.getPath()

        if not @accept(filePath)
            return []

        else
            jsonPath = @getJsonPath(textEditor)
            messages = []

            jsonFile = new File(jsonPath)

            if not jsonFile.existsSync()
                return @executor.execJar(jsonPath, textEditor).then =>
                    parsed = @parseJson(textEditor)
                    @drawLinks(textEditor, parsed[1])
                    return parsed[0]
            else
                parsed = @parseJson(textEditor)
                @drawLinks(textEditor, parsed[1])
                return parsed[0]

    parseJson :(textEditor) ->
        jsonPath = @getJsonPath(textEditor)
        messages = []

        json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })
        data = JSON.parse(json)

        issuesByRegions = data.files


        messages = @collectMesages(issuesByRegions, textEditor.getPath())
        links = @collectLinks(issuesByRegions)

        # ------
        return [messages, links]


    drawLinks:(textEditor, links) ->
        layer = @getOrMakeMarkersLayer(textEditor)
        layer.removeAllMarkers()

        for link in links
            layer.markBufferRange link.to


    collectMesages:(issuesByRegions, filePath) ->
        messages = []
        for key, issues of issuesByRegions
            if issues?
                collapsed = @collapseIssues(issues)
                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                }

                messages.push(msg)
        return messages

    collectLinks:(issuesByRegions) ->
        links=[]
        for key, issues of issuesByRegions
            if issues?
                for issue in issues
                    references=issue.references
                    if references? and references.length > 0
                        for assumption in references
                            link={
                                text:assumption.message
                                from: issues[0].textRange
                                to:assumption.textRange
                            }
                            links.push(link)
        @_log 'links.length=', links.length
        return links

    collapseIssues:(issues) ->
        txt=''
        state = if issues.length>1 then 'multiple' else issues[0].state
        i=0
        for issue in issues
            txt += @issueToString(issue, issues.length>1)
            i++
            if i<issues.length
                txt += '<hr class="issue-split">'

        return {
            message:txt
            state:state
            #they all have same text range, so just take 1st
            textRange:issues[0].textRange
        }


    issueToString:(issue, addState)->
        message = ''
        if addState
            message += @_bage(issue.state.toLowerCase(), issue.state) + ' '
        message += @_bage('level', issue.level) + ' '
        message += @_bage(issue.state.toLowerCase(), issue.predicateType) + ' '
        message += issue.shortDescription
        message += @_assumptionsToString(issue.references)

        return message

    _assumptionsToString: (references)->
        message=''
        if references? and references.length > 0
            message +='<hr class="issue-split">'
            message +=('assumptions: ' + references.length)
            list=''
            for assumption in references
                href='link does not open file :-('#assumption.file #TODO: link to!

                list +='<br>'
                list += @_wrapTag assumption.message, 'a', @_wrapAttr('href', href)
                list +=(' line:' + assumption.textRange[0][0])
                list +=(' col:' + assumption.textRange[0][1])

            message += @_wrapTag list, 'small'


    _wrapAttr: (attr, val) -> attr + '="' + val + '"'

    _wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = ''

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    _bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'

    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance scanner: '
            console.log prefix + msgs.join(' ')

    _warn: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance scanner: '
            console.warn prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
