KT_JSON_DIR='kt_analysis_export'

{Emitter, File} = require 'atom'
{BufferedProcess} = require 'atom'
helpers = require 'atom-linter'
fs = require 'fs'
path = require 'path'
# helpers = require 'atom-linter'

class KtAdvanceScanner

    grammarScopes: ['source.c']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    fs : null
    path: null
    linter: null


    setLinter: (_linter) ->
        @linter=_linter

    constructor: () ->
        @fs=fs
        @_log 'contructor'

    locateJar: ->
        file = atom.packages.resolvePackagePath ('atom-kt-advance')
        if file?
            file = path.join file, 'lib', 'json-kt-advance-5.5.4-jar-with-dependencies.jar'

        return file


    mayBeExecJar: (jsonFile) ->
        @_log 'mayBeExecJar'
        #if not jsonFile.existsSync()
        #    @execJar()

    execJar:(jsonPath, textEditor) ->
        jarPath = @locateJar()
        userDir = @findRoot(jsonPath)

        command = 'java'
        args = ['-jar', jarPath, userDir]

        helpers.exec(command, args, {
            stream: 'stderr',
            cwd: userDir,
            allowEmptyStderr: true
        })
            .then (val) =>
                @parseJson(textEditor, @fs)

        # stdout = (output) ->
        #     if output.startsWith('WARN')
        #         console.warn(output)
        #     else
        #         console.log(output)
        #
        # exit = (code) -> console.log('exited with code ' + code)
        # process = new BufferedProcess({command, args, stdout, exit})

    findRoot:(filePath)->
        for root in atom.project.getPaths()
            relative = path.relative(root, filePath)
            joined = root + path.sep + relative
            if joined == filePath
                return root
        return false


    getJsonPath:(textEditor) ->
        filePath = textEditor.getPath()
        rootDir = @findRoot(filePath)
        # @_log 'rootDir:', rootDir
        relative = path.relative(rootDir, filePath)
        # @_log 'relative path:', relative
        file = path.join rootDir, KT_JSON_DIR, (relative + '.json')
        # @_log 'json path:', file
        return file

    parseJson :(textEditor, fs) ->
        jsonPath = @getJsonPath(textEditor)
        messages = []

        json = fs.readFileSync(jsonPath, { encoding: 'utf-8' })
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

                messages.push(msg)

        return messages

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

    lint: (textEditor) =>

        filePath = textEditor.getPath()
        if not filePath.endsWith('.c')
            return []

        @_log "lint in rootDir=", rootDir = @findRoot(textEditor.getPath())

        jsonPath = @getJsonPath(textEditor)
        messages = []

        jsonFile = new File(jsonPath)
        if not jsonFile.existsSync()
            return @execJar(jsonPath, textEditor)
        else
            return @parseJson(textEditor, @fs)


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

    _bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'

    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance scanner: '
            console.log prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
