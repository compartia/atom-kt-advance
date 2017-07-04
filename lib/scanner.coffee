{File, CompositeDisposable} = require 'atom'

{getChDir} = require 'xml-kt-advance/lib/common/fs'
{XmlReader} = require 'xml-kt-advance/lib/xml/xml_reader'
{FunctionsMap} = require 'xml-kt-advance/lib/xml/xml_types'
{ MapOfLists } = require 'xml-kt-advance/lib/common/collections'
{ ProgressTracker, ProgressTrackerDummie } = require 'xml-kt-advance/lib/common/util';


_ = require 'lodash'
fs = require 'fs'
path = require 'path'
commondir = require 'commondir'

KtAdvanceMarkersLayer = require './markers-layer'
Htmler = require './html-helper'



class KtAdvanceScanner
    scannningPromisePending:false

    grammarScopes: ['source.c', 'source.h', 'source.cpp', 'source.hpp']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    registry: null
    xmlReader: null

    proofObligations :[]
    assumptions : []

    messagesByFile:{}

    violationsOnly: false


    setStatsModel: (@statsModel)->
    setStatsView: (@statsView)->


    constructor: (_registry) ->
        console.log 'contructing kt-scanner'
        @registry = _registry
        @xmlReader = new XmlReader()

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
        return getChDir(filePath)




    ###
        Sets the indie linter interface
        hati-hati! it might be just a Promise.
    ###
    setLinter: (_linter) ->
        @indieLinter = _linter

    ### to be called by 'indie' linter when file is open ###
    scan: (textEditor) ->
        messages = @_lint(textEditor)

        Promise.resolve(messages).then (msgs) =>
            @_submitMessages(msgs, textEditor)

    ### Sends issue-related messages into linter interface ###
    _submitMessages: (fileMessages, textEditor) ->
        @messagesByFile[textEditor.getPath()] = fileMessages
        messages = @_unwrapMessages(@messagesByFile)

        if not @indieLinter?
            console.warn 'scannning before linter is ready!'
        else
            console.log 'messages (total):' + messages.length + "; in file: "+fileMessages.length
            if messages.length is 0
                @indieLinter.deleteMessages()
                return
            @indieLinter.setMessages(@_unwrapMessages(@messagesByFile))


    _unwrapMessages: (messagesByFile) ->
        messages=[]
        for fileName, msgs of messagesByFile
            if msgs?
                for msg in msgs
                    messages.push(msg)

        return messages

    ###
        Tests if a file Ok to analyse. File should be c or cpp.
        deprecated: should be replaced with some Atom aout-of-the box func.
    ###
    accept: (filePath) ->
        #FIXME: in theory this check sould be done by The Linter itself,
        #that's grammarScopes for
        return path.extname(filePath) == '.c'


    _makeErrorMessage: (error, filePath) ->
        result = []
        msg = "process crashed, see dev. console for error details. "
        if error?
            msg+=error.message
        result.push({
            lineNumber: 1
            filePath: filePath
            type: 'error'
            text: msg
        })
        return result

    ## @Overrides
    lint: (textEditor) ->
        @_submitMessages @_lint(textEditor), textEditor

        # return nothing, because this is async indie linter
        # we submit messages via linter interface
        return []

    _lint: (textEditor) =>
        _stats = @statsModel
        _statsView = @statsView
        messages=[]
        markersLayer = @registry.getOrMakeMarkersLayer(textEditor)

        ktDir = @findKtAlaysisDirLocation(textEditor)
        fileAbsolutePath = textEditor.getPath()
        sourceDir = commondir([ktDir, fileAbsolutePath])

        onScanReady = (analysis)=>            
            
            relativePath = path.relative(sourceDir, fileAbsolutePath)

            try
                messages = @collectMesages(markersLayer, [sourceDir, relativePath])
            catch err
                console.error err
                console.error err.stack

            _stats.file_key = relativePath
            _statsView.update()
            return messages


        messages = @scanProject(ktDir, sourceDir, onScanReady)
        return messages



    scanProject:(ktDir, sourceDir, onReady=@onAnalysisReady) ->
        if (not @proofObligations?) || (!@proofObligations.length)
            return @_scanProjectImpl(ktDir, sourceDir, onReady)
        else
            try
                return onReady()
            catch err
                console.error(err)


    _scanProjectImpl:(ktDir, sourceDir, onReady=@onAnalysisReady) ->

        if @scannningInProgress
            return

        
        if not ktDir?
            @statsView.errorMessage.text(
                'No "ch_analysis" dir found')
        
        else                    

            if @scannningPromisePending
                return []

            @scannningPromisePending=true

            tracker = new ProgressTrackerDummie()
            readFunctionsMapTracker = tracker.getSubtaskTracker(10, 'Reading functions map (*._cfile.xml)')
            readDirTracker = tracker.getSubtaskTracker(90, 'Reading Proof Obligations data');


            @xmlReader.readFunctionsMap(path.dirname(ktDir), readFunctionsMapTracker).then(
                (functions) =>
                    console.info('reading functions map complete. Functions:' + functions.length)
                    functionsMap = new FunctionsMap(functions)

                    xmlAnalysis = @xmlReader.readDir(ktDir, functionsMap, readDirTracker)

                    return xmlAnalysis
                ,
                () => return @_makeErrorMessage(null, ktDir)
            ).then(
                (analysis) =>
                    console.info('reading PO data complete. PPOs:' + analysis.ppos.length)
                    console.info('reading PO data complete. SPOs:' + analysis.spos.length)
 
                    @proofObligations = analysis.ppos.concat(analysis.spos);
                    @proofObligations = _.filter(
                        @proofObligations, 
                        (x)->x.stateName!='discharged')

                    @assumptions = analysis.apis;
                    @statsModel.build(@proofObligations, sourceDir)

                    ret=null
                    if onReady?
                        ret = onReady(analysis)

                    @scannningPromisePending=false
                    return ret
            ).catch(
                (e)=>
                    @scannningPromisePending=false
                    return @_makeErrorMessage(e, ktDir)
            )

    onAnalysisReady:(textEditor) ->
        return

    # readAndParseProjectMetrics:(textEditor, jsonPath) ->
    #     projectPath = @_projectPath(textEditor)

    #     data = @readJson(jsonPath)

    #     data.measures.file_title = ""
    #     data.measures.scope = "poject"
    #     @statsModel.setMeasures(projectPath, data.measures)
    #     @statsModel.file_key = projectPath
    #     @statsView.update()
    #     # @statsModel.file_title=projectPath

    parseMetrics: (textEditor, data) ->
        data.measures.line_count = textEditor.getLineCount()
        data.measures.file_title = textEditor.getTitle()
        data.measures.projectPath=@_projectPath(textEditor)
        data.measures.scope = "file"
        @statsModel.setMeasures(textEditor.getPath(), data.measures)
        @statsModel.file_key = textEditor.getPath()
        @statsView.update()


    filterIssues:(issuesByRegions) ->
        filtered={}
        for key, issues of issuesByRegions

            byRegFiltered = []
            for issue in issues
                if 'VIOLATION' == issue.stateName or !@violationsOnly
                    byRegFiltered.push issue

            if byRegFiltered.length>0
                filtered[key]=byRegFiltered

        return filtered


    collectMesages:(markersLayer, paths) ->

        sourceDir = paths[0]
        relativePath = paths[1]
        filePath = path.join(sourceDir, relativePath)

        messages = []
        issuesByFile = _.groupBy(@proofObligations, "file")

        fileIssues = issuesByFile[relativePath];

        fileIssuesByLine = _.groupBy(fileIssues, "line")

        # file=new File(filePath)
        # digest1 =  file.getDigestSync()
        # digest2 =  data.header.digest

        # obsolete = (digest1!=digest2)
        # if obsolete
        #     console.log 'file digest differs: ' + digest1 + ' vs ' + digest2

        #     warning = {
        #         type: 'warning'
        #         filePath: filePath
        #         text: 'File digest differs from what was ananlysed by KT-Advance. Marking all issues as obsolete. Please re-run the analyser'
        #     }
        #     messages.push warning

        obsolete = false        
        for key, issues of fileIssuesByLine
            if issues?

                #in case there are several messages bound to the same region,
                #linter cannot display all of them in a pop-up bubble, so we
                #have to aggregate multiple messages into single one
                collapsed = @collapseIssues(issues, markersLayer, obsolete, sourceDir)

                msg = {
                    type: collapsed.state
                    filePath: filePath
                    range: collapsed.textRange
                    html: collapsed.message
                    # time: collapsed.time
                }

                for issue in issues
                    markersLayer.putMessage issue.key, msg

                messages.push(msg)

        return messages


    ###
    in case there are several messages bound to the same region,
    linter cannot display all of them in a pop-up bubble, so we
    have to aggregate multiple messages into single one ###
    collapseIssues:(issues, markersLayer, obsolete, sourceDir) ->
        txt=''
        state = if issues.length>1 then 'multiple' else issues[0].stateName
        i=0
        for issue in issues
            markedLinks = @issueToString(
                issue
                issues.length>1 #addState
                markersLayer
                obsolete
                sourceDir)

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
            textRange: markersLayer.getMarkerRange(issues[0].key, issues[0].location.textRange)
        }



    issueToString:(issue, addState, markersLayer, obsolete, sourceDir)->
        message = ''
        attrs = ''

        try
            attrs += Htmler.wrapAttr('data-marker-id', issue.key)
            # attrs += Htmler.wrapAttr('data-time', issue.time)
            styleAddon = if obsolete then ' crossed' else ''
            if addState or obsolete
                message += Htmler.bage(issue.stateName.toLowerCase()+styleAddon, issue.stateName) + ' '
            # message += Htmler.bage('obsolete', 'obsolete') + ' '
            levelBageStyle='level'+ styleAddon
            message += Htmler.bage(levelBageStyle, issue.levelLabel) + ' '
            message += Htmler.bage(issue.stateName.toLowerCase(), issue.predicate) + ' '
            message += @_getIssueText(issue)
            message += Htmler.wrapTag '', 'span', attrs

            try
                markedLinks = @_assumptionsToString(issue, markersLayer, sourceDir)
                message += markedLinks
            catch err
                console.log err

        catch err
            console.log err

        return message

    _getIssueText:(item)->
        str=''
        if item.predicateArgument?
            str = str + '(' + item.predicateArgument + ') '
        str = str + item.expression
        if item.discharge? and item.discharge.message?
            str = str + Htmler.wrapTag(item.discharge.message, 'small')
        
        return str


    _assumptionsToString: (issue, markersLayer, sourceDir)->
        message = ''
        if issue.inputs? 
            if issue.inputs.length==1
                apiAssumption = issue.inputs[0]
                dependentPOs = apiAssumption.outputs

                if dependentPOs? and dependentPOs.length > 0
                    message +='<hr class="issue-split">'
                    message +=('dependent POs: ' + dependentPOs.length + ' ')

                    links = ''
                    message +=  Htmler.bage(issue.stateName.toLowerCase(), apiAssumption.type) + ' '
                    list = ''
                    for dpo in dependentPOs
                        list += '<br>'
                        markedLink = @_linkAssumption(dpo, markersLayer, issue.key, sourceDir)
                        list += markedLink[1]

                    links += Htmler.wrapTag list, 'small', Htmler.wrapAttr('class', 'links-'+issue.key)

                    message += Htmler.wrapTag links, 'div', Htmler.wrapAttr('class', 'po-links')
                

            else
                if issue.inputs.length>1
                    console.error issue

        return message

        # references = issue.inputs
        # message = ''
        # if references? and references.length > 0
        #     message +='<hr class="issue-split">'
        #     message +=('assumptions: ' + references.length)

        #     list=''
        #     for assumption in references
        #         list += '<br>'
        #         markedLink = @_linkAssumption(assumption, markersLayer, issue.key)
        #         list += markedLink[1]

        #     message += Htmler.wrapTag list, 'small', Htmler.wrapAttr('class', 'links-'+issue.key)

        # return message


    _linkAssumption: (assumption, markersLayer, bundleId, sourceDir)->
        # projectDir = atom.project.getPaths()[0]
        # dir = path.dirname markersLayer.editor.getPath()
        file = path.join sourceDir, assumption.file #TODO: make properly relative

        marker = markersLayer.markLinkTargetRange(
            assumption.key+'-lnk',
            [[assumption.line,0], [assumption.line,0]],
            # assumption.textRange,
            # XXX: assumption may not have a textRange
            @_getIssueText(assumption),
            bundleId)


        message = ''
        message += Htmler.wrapTag(
            Htmler.rangeToHtml(marker.getBufferRange())
            'a'
            Htmler.wrapAttr('id', 'kt-location')
        )

        message += '&nbsp;&nbsp;'+@_getIssueText(assumption)
        # message += ' line:' + (parseInt(assumption.textRange[0][0])+1)
        # message += ' col:' + assumption.textRange[0][1]


        list=''
        attrs = ' '
        # attrs += Htmler.wrapAttr('href', '#')
        attrs += Htmler.wrapAttr('id', 'kt-assumption-link-src')
        attrs += Htmler.wrapAttr('data-marker-id', assumption.key)
        # attrs += Htmler.wrapAttr('class', 'kt-assumption-link-src kt-assumption-'+marker.id)
        # if assumption.textRange
        # XXX: assumption may not have a textRange
        attrs += Htmler.wrapAttr('line', assumption.line)
        attrs += Htmler.wrapAttr('col', 0)

        attrs += Htmler.wrapAttr('uri', file)

        list += Htmler.wrapTag message, 'span', attrs

        return [marker.id, list]


module.exports = KtAdvanceScanner
