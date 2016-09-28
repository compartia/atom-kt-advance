{Emitter, File} = require 'atom'
path = require 'path'

class KtAdvanceScanner

    grammarScopes: ['source.c']
    scope: 'file'
    lintsOnChange: false #for V2 # Only lint on save
    lintOnFly: false # Only lint on save

    fs : null
    rootDir: null
    path: null

    onDidUpdateMessages: (callback) ->
        console.log "onDidUpdateMessages"
        console.log callback


    constructor: (fileSystem, rootDir) ->
        @fs = fileSystem
        @rootDir = rootDir
        @emitter = new Emitter
        @emitter.on 'did-update-messages', @onDidUpdateMessages

    locateJar: ->
        file = atom.packages.resolvePackagePath ('atom-kt-advance')
        if file?
            file = path.join file, 'lib', 'json-kt-advance-5.5.3-jar-with-dependencies.jar'

        return file


    execJar: ->
        exec = require('child_process').exec

        jarPath = @locateJar()
        @_log 'jar location', jarPath

        userDir = @rootDir
        child = exec 'java -jar ' + jarPath + ' ' + userDir , (error, stdout, stderr) ->
            console.log('Output -> ' + stdout)
            if error?
                console.log('Error -> '+error)
            return

        return

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

            for issue in issues

                # state = if issue.state == 'VIOLATION' then 'error' else if issue.state == 'OPEN' then 'warning' else 'info'
                message = ''
                message += '<b class="badge badge-flexible linter-highlight level">' +issue.level + '</b> '
                message += '<b class="badge badge-flexible linter-highlight ' + issue.state.toLowerCase() + '">' + issue.predicateType + '</b> '

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

                if(issue.state != 'DISCHARGED')
                    messages.push(msg)


        return messages


    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
