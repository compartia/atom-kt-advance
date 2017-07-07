{File, CompositeDisposable} = require 'atom'

{getChDir} = require 'xml-kt-advance/lib/common/fs'
{XmlReader} = require 'xml-kt-advance/lib/xml/xml_reader'
{FunctionsMap} = require 'xml-kt-advance/lib/xml/xml_types'
{ MapOfLists } = require 'xml-kt-advance/lib/common/collections'
{ ProgressTracker, ProgressTrackerDummie, findVarLocation} = require 'xml-kt-advance/lib/common/util';


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
                messages = @collectMesages(textEditor, markersLayer, [sourceDir, relativePath])

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
        # do nothing by default
        return

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


    collectMesages:(textEditor, markersLayer, paths) ->

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
        for line, issues of fileIssuesByLine

            if issues?

                issuesByVar = _.groupBy(issues, "predicateArgument")
                lineStr = textEditor.lineTextForBufferRow(line-1)

                if lineStr?
                    for varname, varissues of issuesByVar
                        textRange = @_findAndFixVariableColumn(varname, lineStr, varissues[0].location.textRange)
                        for iss in varissues
                            iss.location.textRange = textRange
                            #in case there are several messages bound to the same region,
                            #linter cannot display all of them in a pop-up bubble, so we
                            #have to aggregate multiple messages into single one
                            collapsed = @collapseIssues(varissues, markersLayer, obsolete, sourceDir)

                            msg = {
                                type: collapsed.state
                                filePath: filePath
                                range: collapsed.textRange
                                html: collapsed.message
                                # time: collapsed.time
                            }

                            for issue in varissues
                                markersLayer.putMessage issue.key, msg

                            messages.push(msg)

                else
                    console.error('no text at line ' + line)




        return messages

    _findAndFixVariableColumn:(varname, lineStr, textRange) ->
        col = -1
        if varname?
            col = findVarLocation(varname, lineStr)

        if (col>0)
            textRange[0][1] = col
            textRange[1][1] = col + varname.length
        else
            textRange[0][1] = 0
            textRange[1][1] = lineStr.length - 1
        return textRange

    _correctLineNumbers:(textRange) ->
        return {
            start:
                row: textRange[0][0]-1
                column: textRange[0][1]
            end:
                row: textRange[1][0]-1
                column: textRange[1][1]
        }

    ###
    in case there are several messages bound to the same region,
    linter cannot display all of them in a pop-up bubble, so we
    have to aggregate multiple messages into single one ###
    collapseIssues:(issues, markersLayer, obsolete, sourceDir) ->
        txt = ''
        hasViolations = false
        issues = _.sortBy(issues, 'stateName')
        for issue in issues
            if issue.stateName.toLowerCase()=='violation'
                hasViolations=true

        if hasViolations
            state = 'violation'
        else
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
            textRange: markersLayer.getMarkerRange(issues[0].key, @_correctLineNumbers(issues[0].location.textRange))
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
                console.log err.stack

        catch err
            console.log err
            console.log err.stack

        return message

    _getIssueText:(item)->
        str=''
        if item.predicateArgument?
            str = str + '(' + item.predicateArgument + ') '
        str = str + item.expression + ' '
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
                    message += Htmler.bage(issue.stateName.toLowerCase(), apiAssumption.type) + ' '
                    list = ''
                    for dpo in dependentPOs
                        list += '<li>'
                        markedLink = @_linkAssumption(dpo, markersLayer, issue.key, sourceDir)
                        list += markedLink[1]
                        list += '</li>'

                    links += Htmler.wrapTag list, 'ul', Htmler.wrapAttr('class', 'links-'+issue.key)

                    message += Htmler.wrapTag links, 'div', Htmler.wrapAttr('class', 'po-links')


            else
                if issue.inputs.length>1
                    console.error issue

        return message




    _linkAssumption: (dependentPO, markersLayer, bundleId, sourceDir)->

        file = path.join sourceDir, dependentPO.file

        dependentPORange = @_correctLineNumbers(dependentPO.location.textRange)

        marker = markersLayer.markLinkTargetRange(
            dependentPO.key+'-lnk',
            dependentPORange,
            @_getIssueText(dependentPO),
            bundleId)

        markerBufferRange = marker.getBufferRange()
        message = ''
        message += Htmler.wrapTag(
            Htmler.rangeToHtml(markerBufferRange)
            'a'
            Htmler.wrapAttr('id', 'kt-location')
        )

        message += '&nbsp;&nbsp;'+@_getIssueText(dependentPO)

        list=''
        attrs = ' '
        # attrs += Htmler.wrapAttr('href', '#')
        attrs += Htmler.wrapAttr('id', 'kt-assumption-link-src')
        attrs += Htmler.wrapAttr('data-marker-id', dependentPO.key)

        attrs += Htmler.wrapAttr('line', dependentPORange.start.row)
        attrs += Htmler.wrapAttr('col', dependentPORange.start.column)

        attrs += Htmler.wrapAttr('uri', file)

        list += Htmler.wrapTag message, 'span', attrs

        return [marker.id, list]



    parseMetrics: (textEditor, data) ->
        data.measures.line_count = textEditor.getLineCount()
        data.measures.file_title = textEditor.getTitle()
        data.measures.projectPath=@_projectPath(textEditor)
        data.measures.scope = "file"
        @statsModel.setMeasures(textEditor.getPath(), data.measures)
        @statsModel.file_key = textEditor.getPath()
        @statsView.update()



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

module.exports = KtAdvanceScanner
