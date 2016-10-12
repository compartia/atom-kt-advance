KT_JSON_DIR='kt_analysis_export'

{File, CompositeDisposable} = require 'atom'
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
    registry: null
    executor: null
    bubbleInterval: 150


    constructor: () ->
        @_log 'contructor'
        @executor=new KtAdvanceJarExecutor()
        @layersByEditorId=[]
        @subscriptions = new CompositeDisposable()

        # @observer = new MutationObserver (mutations) ->
        #     mutations.forEach (mutation) ->
        #         console.error mutation.type

        @subscriptions.add(
            atom.config.observe 'linter.inlineTooltipInterval',
                (newValue) =>
                    @bubbleInterval = newValue*2
                    console.error @bubbleInterval
        )


    setLinter: (_linter) ->
        @linter=_linter

    setRegistry: (_registry) ->
        @registry = _registry
        # console.warn @registry

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
        # @_log 'creating marker layer for editor id '+ textEditor.id, '....'
        if not @layersByEditorId[textEditor.id]?
            @layersByEditorId[textEditor.id] = new KtAdvanceColorLayer(textEditor)
            @_log 'created marker layer for editor id '+ textEditor.id
        return @layersByEditorId[textEditor.id]


    # getDecorationsByMarker: (textEditor, marker)->
    #     selected =[]
    #     decorations = textEditor.getOverlayDecorations([])
    #     for decor in decorations
    #         if decor.getMarker().id == marker.id
    #             if decor.properties.item
    #                 selected.push decor
    #     return selected


    updateLinks: (el, textEditor) ->
        Promise.resolve(el).then (value) =>

            links = value.querySelectorAll("#kt-assumption-link-src")
            # console.warn 'links:'
            # console.warn links
            # Promise.resolve(links).then (lnks)=>
            if links?
                markersLayer = @getOrMakeMarkersLayer textEditor
                for link in links
                    @updateLinkLineNumber(link, markersLayer)

        return

    updateLinkLineNumber:(link, markersLayer)->
        markerId = parseInt(link.getAttribute('data-marker-id'))
        marker = markersLayer.getMarker(markerId)
        range = marker.getScreenRange()


        el= link.querySelector("#kt-location")
        el.innerHTML = 'line:'+(range.start.row+1)+' col:'+range.start.column
        file = link.getAttribute('uri')
        link.onclick = ()=>
            options = {
                initialLine: range.start.row
                initialColumn: range.start.column
            }
            atom.workspace.open(file, options)

        return el

    scan: (textEditor) ->
        editorLinter= @registry?.getActiveEditorLinter()

        textEditor.onDidAddDecoration (decoration)=>
            if decoration.properties.type=='overlay'
                el = decoration.properties.item
                if el? and el.querySelector?
                    setTimeout( =>
                        @updateLinks(el, textEditor)
                    , 250)
        #TODO: use @bubbleInterval x 2 from Linter config


        # editorLinter?.onShouldUpdateBubble (x)=>
        #     decorations = textEditor.getOverlayDecorations([])
        #     for decor in decorations
        #         decor.properties.item.appendChild(@makeArtem())
        #         console.warn decor.properties.item

            # els = document.getElementsByClassName('kt-assumption-link-src')
            # if els
            #     for el in els
            #         el.appendChild(@makeArtem())


        # markersLayer = @getOrMakeMarkersLayer(textEditor)
        # editorLinter?.onDidMessageAdd (msg) =>
        #     marker = editorLinter.markers.get(msg)
        #     decorations = @getDecorationsByMarker(textEditor, marker)
        #     for decor in decorations
        #         # decor.properties.item.appendChild(@makeArtem())
        #         console.warn decor.properties.item

            # if msg.linkedMarkerIds
            #     for arr in msg.linkedMarkerIds
            #         for markerId in arr
            #             console.warn markerId
            #             markersLayer.updateLinks(markerId)

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
                    return parsed[0]
            else
                parsed = @parseJson(textEditor)
                return parsed[0]

    parseJson :(textEditor) ->
        jsonPath = @getJsonPath(textEditor)
        messages = []

        json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })
        data = JSON.parse(json)

        issuesByRegions = data.files


        markersLayer = @getOrMakeMarkersLayer(textEditor)
        markersLayer.removeAllMarkers()

        messages = @collectMesages(issuesByRegions, textEditor.getPath(), markersLayer)
        links = @collectLinks(issuesByRegions)

        # ------
        return [messages, links]


    collectMesages:(issuesByRegions, filePath, markersLayer) ->
        messages = []
        i=0;
        for key, issues of issuesByRegions
            if issues?
                collapsed = @collapseIssues(issues, markersLayer)
                i++
                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                    linkedMarkerIds: collapsed.linkedMarkerIds
                    ktId: i
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

    collapseIssues:(issues, markersLayer) ->
        txt=''
        markers=[]
        state = if issues.length>1 then 'multiple' else issues[0].state
        i=0
        for issue in issues
            markedLinks=@issueToString(issue, issues.length>1, markersLayer)

            txt += markedLinks[1]
            markers.push markedLinks[0]
            i++
            if i<issues.length
                txt += '<hr class="issue-split">'

        return {
            message:txt
            state:state
            linkedMarkerIds:markers
            #they all have same text range, so just take 1st
            textRange:issues[0].textRange
        }


    issueToString:(issue, addState, markersLayer)->
        message = ''
        if addState
            message += @_bage(issue.state.toLowerCase(), issue.state) + ' '
        message += @_bage('level', issue.level) + ' '
        message += @_bage(issue.state.toLowerCase(), issue.predicateType) + ' '
        message += issue.shortDescription

        markedLinks= @_assumptionsToString(issue.references, markersLayer)
        message += markedLinks[1]

        return [markedLinks[0], message]

    _assumptionsToString: (references, markersLayer)->
        message=''
        markers=[]
        if references? and references.length > 0
            message +='<hr class="issue-split">'
            message +=('assumptions: ' + references.length)
            list=''
            for assumption in references
                list +='<br>'
                markedLink=@_linkAssumption(assumption, markersLayer)
                list+=markedLink[1]
                markers.push markedLink[0]

            message += @_wrapTag list, 'small'

        return [markers, message]

    _linkAssumption: (assumption, markersLayer)->

        dir = path.dirname markersLayer.editor.getPath()
        file = path.join dir, assumption.file #TODO: make properly relative

        decoration = markersLayer.markBufferRange assumption.textRange
        marker = decoration.getMarker()

        message = ''
        message += @_wrapTag '', 'span', @_wrapAttr('id', 'kt-location')
        message += '&nbsp;&nbsp;'+assumption.message
        message += ' line:' + (parseInt(assumption.textRange[0][0])+1)
        message += ' col:' + assumption.textRange[0][1]


        list=''
        attrs = ' '
        attrs += @_wrapAttr('href', '#')
        attrs += @_wrapAttr('id', 'kt-assumption-link-src')
        attrs += @_wrapAttr('data-marker-id', marker.id)
        attrs += @_wrapAttr('class', 'kt-assumption-link-src kt-assumption-'+marker.id)
        attrs += @_wrapAttr('line', assumption.textRange[0][0])
        attrs += @_wrapAttr('col', assumption.textRange[0][1])
        attrs += @_wrapAttr('uri', file)

        list += @_wrapTag message, 'a', attrs

        return [marker.id, list]

    _wrapAttr: (attr, val) -> attr + '="' + val + '"'+' '

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
