KT_JSON_DIR='kt_analysis_export'

Logger = require './logger'

{File, CompositeDisposable} = require 'atom'
fs = require 'fs'
path = require 'path'

KtAdvanceJarExecutor = require './jar-exec'
KtAdvanceMarkersLayer = require './markers-layer'
Htmler = require './html-helper'

class KtAdvanceScanner

    grammarScopes: ['source.c']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    linter: null
    registry: null
    executor: null




    constructor: (_registry) ->
        Logger.log 'contructor'
        @registry=_registry
        @executor=new KtAdvanceJarExecutor()
        @layersByEditorId=[]



    setLinter: (_linter) ->
        @linter=_linter


    findKtAlaysisDirLocation:(textEditor) ->
        filePath = textEditor.getPath()
        parent = path.dirname(filePath)

        k=0
        while parent!=null && parent!='' && (parent?) && parent!='\\' && parent!='/' && k<100
            k++
            dir = new File(path.join parent, 'ch_analysis')
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

    scan: (textEditor) ->
        messages = @_lint(textEditor)

        Promise.resolve(messages).then (value) =>
            @_submitMessages(value)


    _submitMessages:(messages)->
        Logger.log 'messages:', messages.length
        if messages.length is 0
            @linter?.deleteMessages()
            return
        @linter?.setMessages(messages)

    accept: (filePath) ->
        return path.extname(filePath) == '.c'

    ## @Overrides
    lint: (textEditor) ->
        # do nothing, because this is async indie linter
        #we  have own onSave listener.
        return []

    _lint: (textEditor) =>
        filePath = textEditor.getPath()

        if not @accept(filePath)
            return []

        else
            jsonPath = @getJsonPath(textEditor)
            messages = []

            jsonFile = new File(jsonPath)

            if not jsonFile.existsSync()
                #run JAR first to generate json-s
                return @executor.execJar(jsonPath, textEditor).then =>
                    return @parseJson(textEditor)
            else
                return @parseJson(textEditor)


    parseJson :(textEditor) ->
        jsonPath = @getJsonPath(textEditor)
        messages = []

        json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })
        data = JSON.parse(json)

        issuesByRegions = data.posByKey

        markersLayer = @registry.getOrMakeMarkersLayer(textEditor)
        messages = @collectMesages(issuesByRegions, textEditor.getPath(), markersLayer)

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

            txt += markedLinks
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
            message += Htmler.bage(issue.state.toLowerCase(), issue.state) + ' '
        message += Htmler.bage('level', issue.level) + ' '
        message += Htmler.bage(issue.state.toLowerCase(), issue.predicateType) + ' '
        message += issue.shortDescription
        message += Htmler.wrapTag '', 'span', Htmler.wrapAttr('data-marker-id', issue.referenceKey)

        markedLinks= @_assumptionsToString(issue, markersLayer)
        message += markedLinks

        return message

    _assumptionsToString: (issue , markersLayer)->
        references = issue.references
        message = ''
        if references? and references.length > 0
            message +='<hr class="issue-split">'
            message +=('assumptions: ' + references.length)

            list=''
            for assumption in references
                list += '<br>'
                markedLink = @_linkAssumption(assumption, markersLayer, issue.referenceKey)
                list += markedLink[1]

            message += Htmler.wrapTag list, 'small', Htmler.wrapAttr('class', 'links-'+issue.referenceKey)

        return message

    _linkAssumption: (assumption, markersLayer, bundleId)->

        dir = path.dirname markersLayer.editor.getPath()
        file = path.join dir, assumption.file #TODO: make properly relative

        marker = markersLayer.markLinkTargetRange(
            assumption.referenceKey+'-lnk',
            assumption.textRange,
            assumption.message,
            bundleId)


        message = ''
        message += Htmler.wrapTag(
            Htmler.rangeToHtml(marker.getBufferRange())
            'a'
            Htmler.wrapAttr('id', 'kt-location')
        )

        message += '&nbsp;&nbsp;'+assumption.message
        # message += ' line:' + (parseInt(assumption.textRange[0][0])+1)
        # message += ' col:' + assumption.textRange[0][1]


        list=''
        attrs = ' '
        # attrs += Htmler.wrapAttr('href', '#')
        attrs += Htmler.wrapAttr('id', 'kt-assumption-link-src')
        attrs += Htmler.wrapAttr('data-marker-id', assumption.referenceKey)
        # attrs += Htmler.wrapAttr('class', 'kt-assumption-link-src kt-assumption-'+marker.id)
        attrs += Htmler.wrapAttr('line', assumption.textRange[0][0])
        attrs += Htmler.wrapAttr('col', assumption.textRange[0][1])
        attrs += Htmler.wrapAttr('uri', file)

        list += Htmler.wrapTag message, 'span', attrs

        return [marker.id, list]


module.exports = KtAdvanceScanner
