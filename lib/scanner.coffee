{File, CompositeDisposable} = require 'atom'

fs = require 'fs'
path = require 'path'
# moment= require 'moment'

{KtAdvanceJarExecutor,VERSION} = require './jar-exec'

KtAdvanceMarkersLayer = require './markers-layer'
Htmler = require './html-helper'


KT_JSON_DIR='kt_analysis_export_'+VERSION

class KtAdvanceScanner

    grammarScopes: ['source.c', 'source.h', 'source.cpp', 'source.hpp']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    registry: null
    executor: null

    messagesByFile:{}

    violationsOnly: false


    setStatsModel: (@statsModel)->
    setStatsView: (@statsView)->


    constructor: (_registry) ->
        console.log 'contructing kt-scanner'
        @registry = _registry
        @executor = new KtAdvanceJarExecutor()

        @subscriptions = new CompositeDisposable
        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.violationsOnly',
                (newValue) => (
                    @violationsOnly = newValue
                    console.log 'violationsOnly has changed:' + @violationsOnly
                )

        )



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
    _submitMessages: (fileMessages, textEditor) ->
        @messagesByFile[textEditor.getPath()] = fileMessages
        messages = @_unwrapMessages()

        if not @indieLinter?
            console.warn 'scannning before linter is ready!'
        else
            console.log 'messages (total):' + messages.length + "; in file: "+fileMessages.length
            if messages.length is 0
                @indieLinter.deleteMessages()
                return
            @indieLinter.setMessages(@_unwrapMessages(@messagesByFile))


    _unwrapMessages: () ->
        messages=[]
        for fileName, msgs of @messagesByFile
            for msg in msgs
                messages.push(msg)

        return messages
    ###
        Tests if a file Ok to analyse. File should be c or cpp.
        deprecated: should be replaced with some Atom aout-of-the box func.
    ###
    accept: (filePath) ->
        return path.extname(filePath) == '.c'


    makeErrorMessage: (error, filePath) ->
        result = []
        result.push({
            lineNumber: 1
            filePath: filePath
            type: 'error'
            text: "process crashed, see console for error details. "+error.message
        })
        return result

    ## @Overrides
    lint: (textEditor) ->
        @_submitMessages @_lint(textEditor), textEditor

        # return nothing, because this is async indie linter
        # we submit messages via linter interface
        return []

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
                console.error(e.message)
                console.error(e.stack)
                return @makeErrorMessage(e, filePath)


    ###
        Reads data from given .json file and converts
        it to array of linter messages
    ###
    parseJson :(textEditor, jsonPath) ->
        try
            json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })

            data = JSON.parse(json)

            @statsModel.measures=data.measures
            @statsView.update()

            markersLayer = @registry.getOrMakeMarkersLayer(textEditor)
            messages = @collectMesages(data, textEditor.getPath(), markersLayer)

            return messages

        catch e
            console.error (e.message)
            console.error (e.stack)
            return @makeErrorMessage(e, textEditor.getPath())



    filterIssues:(issuesByRegions) ->
        filtered={}
        for key, issues of issuesByRegions

            byRegFiltered = []
            for issue in issues
                if 'VIOLATION' == issue.state or !@violationsOnly
                    byRegFiltered.push issue

            if byRegFiltered.length>0
                filtered[key]=byRegFiltered

        return filtered


    collectMesages:(data, filePath, markersLayer) ->
        messages = []
        issuesByRegions = @filterIssues data.posByKey.map


        file=new File(filePath)
        digest1 =  file.getDigestSync()
        digest2 =  data.header.digest

        obsolete = (digest1!=digest2)
        if obsolete
            console.log 'file digest differs: ' + digest1 + ' vs ' + digest2

            warning = {
                type: 'warning'
                filePath: filePath
                text: 'File digest differs from what was ananlysed by KT-Advance. Marking all issues as obsolete. Please re-run the analyser'
            }
            messages.push warning

        #
        # stats = fs.statSync(filePath)
        # mtime = moment(stats.mtime)
        # # console.log(mtime)


        # i=0;
        for key, issues of issuesByRegions
            if issues?


                #in case there are several messages bound to the same region,
                #linter cannot display all of them in a pop-up bubble, so we
                #have to aggregate multiple messages into single one
                collapsed = @collapseIssues(issues, markersLayer, obsolete)

                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                    time: collapsed.time
                }

                for issue in issues
                    markersLayer.putMessage issue.referenceKey, msg

                messages.push(msg)

        return messages


    ###
        in case there are several messages bound to the same region,
        linter cannot display all of them in a pop-up bubble, so we
        have to aggregate multiple messages into single one ###
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
            # 05/31/2016 16:55:52
            # time: moment(issues[0].time,  "MM/DD/YYYY HH:mm:ss")
            #XXX: per issue time!! or use minimal
            # linkedMarkerIds:markers
            #they all have same text range, so just take 1st
            textRange: markersLayer.getMarkerRange(issues[0].referenceKey, issues[0].textRange)
        }






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
