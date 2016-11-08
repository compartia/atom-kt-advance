{File} = require 'atom'

fs = require 'fs'
path = require 'path'
moment= require 'moment'

{KtAdvanceJarExecutor,VERSION} = require './jar-exec'

KtAdvanceMarkersLayer = require './markers-layer'
Htmler = require './html-helper'


KT_JSON_DIR='kt_analysis_export_'+VERSION

class KtAdvanceScanner

    grammarScopes: ['source.c', 'source.h', 'source.cpp', 'source.hpp']
    scope: 'file'
    lintsOnChange: true #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    registry: null
    executor: null


    constructor: (_registry) ->
        console.log 'contructing kt-scanner'
        @registry = _registry
        @executor = new KtAdvanceJarExecutor()


    findKtAlaysisDirLocation:(textEditor) ->
        filePath = textEditor.getPath()
        parent = path.dirname(filePath)

        k=0
        # TODO: test on Wintel
        while parent!=null && parent!='' && (parent?) && parent!='\\' && parent!='/' && k<100
            k++
            # TODO: make 'ch_analysis' configurable
            dir = new File(path.join parent, 'ch_analysis')
            if dir.existsSync()
                return parent

            parent = path.dirname(parent)


        return null

    getJsonPath:(textEditor) ->
        filePath = textEditor.getPath()
        ktDir = @findKtAlaysisDirLocation(textEditor)
        if ktDir?
            relative = path.relative(ktDir, filePath)
            file = path.join ktDir, KT_JSON_DIR,  (relative + '.json')
            return file
        else
            return null

    ###
        Sets the indie linter interface
        hati-hati! it might be just a Promise.
    ###
    setLinter: (_linter) ->
        @indieLinter = _linter

    ### to be called by 'indie' linter when file is open ###
    scan: (textEditor) ->
        messages = @_lint(textEditor)

        Promise.resolve(messages).then (value) =>
            @_submitMessages(value, textEditor)

    ### Sends issue-related messages into linter interface ###
    _submitMessages:(messages, textEditor)->
        Promise.resolve(@indieLinter).then(linter) ->
            if not linter?
                console.error 'scannning before linter is ready!'
            else
                console.log 'messages:', messages.length
                if messages.length is 0
                    linter.deleteMessages()
                    return
                linter.setMessages(messages)

    ###
        Tests if a file Ok to analyse. File should be c or cpp.
        deprecated: should be replaced with some Atom aout-of-the box func.
    ###
    accept: (filePath) ->
        return path.extname(filePath) == '.c'


    makeErrorMessage: (error, filePath) ->
        result = []
        console.error(error.message)
        console.error(error.stack)
        result.push({
            lineNumber: 1
            filePath: filePath
            type: 'error'
            text: "process crashed, see console for error details."
        })
        return result

    ## @Overrides
    lint: (textEditor) ->
        # do nothing, because this is async indie linter
        #we  have own onSave listener.
        return @_lint(textEditor)

    _lint: (textEditor) =>
        filePath = textEditor.getPath()

        if not @accept(filePath)
            return []

        else
            try
                jsonPath = @getJsonPath(textEditor)
                messages = []

                jsonFile = new File(jsonPath)

                if not jsonFile.existsSync()
                    # in case no .json is there we have to run external analyser
                    # run JAR first to generate json-s
                    return @executor.execJar(jsonPath, textEditor).then =>
                        return @parseJson(textEditor, jsonPath)
                else
                    return @parseJson(textEditor, jsonPath)

            catch e
                return @makeErrorMessage(e, filePath)


    ###
        Reads data from given .json file and converts
        it to array of linter messages
    ###
    parseJson :(textEditor, jsonPath) ->
        try
            json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })

            data = JSON.parse(json)

            markersLayer = @registry.getOrMakeMarkersLayer(textEditor)
            messages = @collectMesages(data, textEditor.getPath(), markersLayer)

            return messages

        catch e
            return @makeErrorMessage(e, textEditor.getPath())



    collectMesages:(data, filePath, markersLayer) ->

        issuesByRegions = data.posByKey.map


        file=new File(filePath)
        digest1 =  file.getDigestSync()
        digest2 =  data.header.digest

        #
        # stats = fs.statSync(filePath)
        # mtime = moment(stats.mtime)
        # # console.log(mtime)

        messages = []
        # i=0;
        for key, issues of issuesByRegions
            if issues?
                obsolete = (digest1!=digest2)
                if obsolete
                    console.log 'file digest differs: ' + digest1 + ' vs ' + digest2

                #in case there are severla messages bound to the same region,
                #linter cannot display all of them in a pop-up bubble, so we
                #have to aggregate multiple messages into single one
                collapsed = @collapseIssues(issues, markersLayer, obsolete)

                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                    time: collapsed.time
                    trace: collapsed.assumptions
                }

                for issue in issues
                    markersLayer.putMessage issue.referenceKey, msg

                messages.push(msg)

        return messages


    collapseIssues:(issues, markersLayer, obsolete) ->
        txt=''
        state = if issues.length>1 then 'multiple' else issues[0].state
        i=0
        for issue in issues
            markedLinks = @issueToString(
                issue
                issues.length>1 #addState
                markersLayer
                obsolete)

            txt += markedLinks
            i++
            if i<issues.length
                txt += '<hr class="issue-split">'

        return {
            message:txt
            state: if obsolete then 'obsolete' else state
            time: moment(issues[0].time)
            # assumptions: assumptions
            #XXX: per issue time!! or use minimal
            # linkedMarkerIds:markers
            #they all have same text range, so just take 1st
            textRange: markersLayer.getMarkerRange(issues[0].referenceKey, issues[0].textRange)
            assumptions: @assumptionsToTraces(issues[0], markersLayer)
        }

    assumptionsToTraces: (issue , markersLayer)->
        traces=[]
        references = issue.references
        message = ''
        dir = path.dirname markersLayer.editor.getPath()

        if references? and references.length > 0

            for assumption in references
                @_linkAssumption(assumption, markersLayer, issue.referenceKey)
                file = path.join dir, assumption.file #TODO: make properly relative

                traces.push {
                    type: 'assumption'
                    filePath: file
                    range: markersLayer.getMarkerRange(assumption.referenceKey, assumption.textRange)
                    html: assumption.message
                }


        return traces


    issueToString:(issue, addState, markersLayer, obsolete)->
        message = ''
        attrs = ''

        attrs += Htmler.wrapAttr('data-marker-id', issue.referenceKey)
        # attrs += Htmler.wrapAttr('data-time', issue.time)
        styleAddon = if obsolete then ' crossed' else ''
        if addState or obsolete
            message += Htmler.bage(issue.state.toLowerCase()+styleAddon, issue.state) + ' '
        # message += Htmler.bage('obsolete', 'obsolete') + ' '
        levelBageStyle='level'+ styleAddon
        message += Htmler.bage(levelBageStyle, issue.level) + ' '
        message += Htmler.bage(issue.state.toLowerCase(), issue.predicateType) + ' '
        message += issue.shortDescription
        message += Htmler.wrapTag '', 'span', attrs

        return message



    _linkAssumption: (assumption, markersLayer, bundleId)->

        dir = path.dirname markersLayer.editor.getPath()
        file = path.join dir, assumption.file #TODO: make properly relative

        marker = markersLayer.markLinkTargetRange(
            assumption.referenceKey+'-lnk',
            assumption.textRange,
            assumption.message,
            bundleId)         


module.exports = KtAdvanceScanner
