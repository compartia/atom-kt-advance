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
            file = path.join file, 'lib', 'json-kt-advance-5.5.3-jar-with-dependencies.jar'

        return file

    mayBeExecJar: ->
        fileObj = new File(
            path.join(@rootDir, 'kt_analysis_export', 'kt.json'))

        if not fileObj.existsSync()
            @execJar()

    execJar: ->
        jarPath = @locateJar()
        userDir = @rootDir

        command = 'java'
        args = ['-jar', jarPath, userDir]

        stdout = (output) -> console.log(output)
        exit = (code) -> console.log('exited with code ' + code)
        process = new BufferedProcess({command, args, stdout, exit})


    _bage:(clazz, body) ->
        '<span class="badge badge-flexible linter-highlight ' + clazz + '">' + body + '</span>'

    lint: (textEditor) =>
        messages = []

        filePath = textEditor.getPath()
        source = textEditor.getText()

        @_log "lint called in ", filePath, "rootDir=", @rootDir

        file = path.join @rootDir, 'kt_analysis_export', 'kt.json'
        fileObj = new File(file)

        if not fileObj.existsSync()
            @execJar()

        else
            @_log("reading=", file)

            json = @fs.readFileSync(file, { encoding: 'utf-8' })
            data = JSON.parse(json)

            issues = data.files[filePath]

            if issues?
                for issue in issues
                    message = ''
                    message += @_bage('level', issue.level) + ' '
                    message += @_bage(issue.state.toLowerCase(), issue.predicateType) + ' '
                    message += issue.shortDescription

                    if (issue.references.length > 0)
                        message +=('<br>assumptions:' + issue.references.length)
                        for assumption in issue.references
                            href=assumption.file

                            message +='<br><a data-path="'
                            message += href
                            message += '">'
                            message += assumption.message
                            message += '</a>'
                            message +=(' line:' + assumption.textRange[0][0])
                            message +=(' col:' + assumption.textRange[0][1])

                    msg = {
                        type: issue.state
                        filePath: filePath
                        range: issue.textRange
                        html: message
                    }

                    # marker = textEditor.markBufferRange(issue.textRange, {})
                    # options={
                    #     class:'kt-issue-decor'
                    #     type:'line'
                    # }
                    # textEditor.decorateMarker(marker, options)

                    if(issue.state != 'DISCHARGED')
                        messages.push(msg)


        for marker in textEditor.getMarkers()
            console.log marker
        return messages


    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
