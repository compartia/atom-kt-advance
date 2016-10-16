KT_JSON_DIR='kt_analysis_export'

{File, CompositeDisposable} = require 'atom'
fs = require 'fs'
path = require 'path'

KtAdvanceJarExecutor = require './jar-exec'
KtAdvanceMarkersLayer = require './markers-layer'


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

    findKtAlaysisDirLocation:(textEditor) ->
        filePath = textEditor.getPath()

        parent = path.dirname(filePath)
        # console.error parent
        k=0
        while parent!=null && parent!='' && (parent?) && parent!='\\' && parent!='/' && k<100
            k++
            dir = new File(path.join parent, 'ch_analysis')
            # console.error dir
            if dir.existsSync()
                return parent

            parent = path.dirname(parent)


        return null

    getJsonPath:(textEditor) ->
        filePath = textEditor.getPath()
        ktDir = @findKtAlaysisDirLocation(textEditor)
        if ktDir
            relative = path.relative(ktDir, filePath)
            file = path.join ktDir, KT_JSON_DIR,  (relative + '.json')
            return file
        return null

    getOrMakeMarkersLayer: (textEditor)->
        # @_log 'creating marker layer for editor id '+ textEditor.id, '....'
        if not @layersByEditorId[textEditor.id]?
            @layersByEditorId[textEditor.id] = new KtAdvanceMarkersLayer(textEditor)
            @_log 'created marker layer for editor id '+ textEditor.id
        return @layersByEditorId[textEditor.id]

    scan: (textEditor) ->
        markersLayer = @getOrMakeMarkersLayer(textEditor)
        messages = @_lint(textEditor)

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
        # scan: (textEditor)
        return []
        # messages =  @_lint(textEditor)

    _lint: (textEditor) =>
        filePath = textEditor.getPath()

        if not @accept(filePath)
            return []

        else
            jsonPath = @getJsonPath(textEditor)
            messages = []

            jsonFile = new File(jsonPath)

            if not jsonFile.existsSync()
                return @executor.execJar(jsonPath, textEditor).then =>
                    return @parseJson(textEditor)
            else
                return @parseJson(textEditor)


    parseJson :(textEditor) ->
        jsonPath = @getJsonPath(textEditor)
        messages = []

        # try
        json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })
        data = JSON.parse(json)

        issuesByRegions = data.posByKey

        markersLayer = @getOrMakeMarkersLayer(textEditor)
        # markersLayer.removeAllMarkers()

        messages = @collectMesages(issuesByRegions, textEditor.getPath(), markersLayer)
        # catch e
        #     console.error e

        return messages


    collectMesages:(issuesByRegions, filePath, markersLayer) ->
        messages = []
        # i=0;
        for key, issues of issuesByRegions
            if issues?
                collapsed = @collapseIssues(issues, markersLayer)
                # i++
                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                    # linkedMarkerIds: collapsed.linkedMarkerIds
                    # ktId: i
                }

                for issue in issues
                    markersLayer.putMessage issue.referenceKey, msg

                messages.push(msg)
        return messages

     
    collapseIssues:(issues, markersLayer) ->
        txt=''
        state = if issues.length>1 then 'multiple' else issues[0].state
        i=0
        for issue in issues
            markedLinks=@issueToString(issue, issues.length>1, markersLayer)

            txt += markedLinks[1]
            i++
            if i<issues.length
                txt += '<hr class="issue-split">'

        return {
            message:txt
            state:state
            # linkedMarkerIds:markers
            #they all have same text range, so just take 1st
            textRange: markersLayer.getMarkerRange(issues[0].referenceKey, issues[0].textRange)
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

        marker = markersLayer.markLinkTargetRange(
            assumption.referenceKey+'-lnk',
            assumption.textRange, assumption.message)


        message = ''
        message += @_wrapTag '', 'span', @_wrapAttr('id', 'kt-location')
        message += '&nbsp;&nbsp;'+assumption.message
        message += ' line:' + (parseInt(assumption.textRange[0][0])+1)
        message += ' col:' + assumption.textRange[0][1]


        list=''
        attrs = ' '
        attrs += @_wrapAttr('href', '#')
        attrs += @_wrapAttr('id', 'kt-assumption-link-src')
        attrs += @_wrapAttr('data-marker-id', assumption.referenceKey)
        # attrs += @_wrapAttr('class', 'kt-assumption-link-src kt-assumption-'+marker.id)
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
