{Emitter, File} = require 'atom'
{BufferedProcess} = require 'atom'

path = require 'path'

class KtAdvanceScanner

    grammarScopes: ['source.c']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    fs : null
    rootDir: null
    path: null

    constructor: (fileSystem, rootDir) ->
        @fs = fileSystem
        @rootDir = rootDir

    locateJar: ->
        file = atom.packages.resolvePackagePath ('atom-kt-advance')
        if file?
            file = path.join file, 'lib', 'json-kt-advance-5.5.4-jar-with-dependencies.jar'

        return file

    mayBeExecJar: (jsonFile) ->
        if not jsonFile?
            jsonFile = new File(path.join(@rootDir, 'kt_analysis_export', 'kt.json'))

        if not jsonFile.existsSync()
            @execJar()

    execJar: ->
        jarPath = @locateJar()
        userDir = @rootDir

        command = 'java'
        args = ['-jar', jarPath, userDir]

        stdout = (output) ->
            if output.startsWith('WARN')
                console.warn(output)
            else
                console.log(output)

        exit = (code) -> console.log('exited with code ' + code)
        process = new BufferedProcess({command, args, stdout, exit})


    _bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'


    getJsonPath:(textEditor) ->
        filePath = textEditor.getPath()
        relative = path.relative(@rootDir, filePath)
        @_log 'relative path:', relative
        file = path.join @rootDir, 'kt_analysis_export', (relative + '.json')
        @_log 'json path:', file
        return file

    lint: (textEditor) =>

        @_log "lint in rootDir=", @rootDir
        jsonPath = @getJsonPath(textEditor)
        messages = []

        jsonFile = new File(jsonPath)
        @mayBeExecJar(jsonFile)

        if not jsonFile.existsSync()
            @execJar()

        else
            @_log("reading=", jsonPath)

            json = @fs.readFileSync(jsonPath, { encoding: 'utf-8' })
            data = JSON.parse(json)

            issuesByRegions = data.files

            for key, issues of issuesByRegions
                if issues?

                    collapsed = @collapseIssues(issues)
                    msg = {
                        type: collapsed.state
                        filePath: textEditor.getPath()
                        range: collapsed.textRange
                        html: collapsed.message
                    }

                    # marker = textEditor.markBufferRange(issue.textRange, {})
                    # options={
                    #     class:'kt-issue-decor'
                    #     type:'line'
                    # }
                    # textEditor.decorateMarker(marker, options)

                    #if(issue.state != 'DISCHARGED')
                    messages.push(msg)


        for marker in textEditor.getMarkers()
            console.log marker
        return messages

    collapseIssues:(issues) ->
        txt=''
        state = if issues.length>1 then 'multiple' else issues[0].state
        i=0
        for issue in issues
            txt += @issueToString(issue, issues.length>1)
            i++
            if i<issues.length
                txt += '<hr class="issue-split">'
            #maximum state
            # if issue.state=='VIOLATION'
            #     state='VIOLATION'

        return {
            message:txt
            state:state
            textRange:issues[0].textRange #they all have same text range!
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
                href=assumption.file #TODO: link to!

                list +='<br>'
                list += @_wrapTag assumption.message, 'a', @_wrapAttr('data-path', href)
                list +=(' line:' + assumption.textRange[0][0])
                list +=(' col:' + assumption.textRange[0][1])

            message += @_wrapTag list, 'small'

    _wrapAttr: (attr, val) -> attr + '="' + val + '"'

    _wrapTag: (str, tag, attr) ->
        attrAdd = ' '+attr
        if not attr?
            attrAdd = ''

        '<' + tag + attrAdd + '>' + str + '</' + tag + '>'

    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
