{Emitter} = require 'atom'
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


    constructor:(fileSystem, rootDir) ->
        @fs = fileSystem
        @rootDir = rootDir
        @emitter = new Emitter
        @emitter.on 'did-update-messages', @onDidUpdateMessages



    lint: (textEditor) =>
        filePath = textEditor.getPath()
        source = textEditor.getText()

        @_log("lint called", filePath)
        @_log("rootDir=", @rootDir)

        file = path.join @rootDir, 'kt_analysis_export', 'kt.json'


        @_log("reading=", file)

        json = @fs.readFileSync(file, { encoding: 'utf-8' })
        data = JSON.parse(json)

        messages=[]

        issues=data.files[filePath]

        for issue in issues



            # state = if issue.state == 'VIOLATION' then 'error' else if issue.state == 'OPEN' then 'warning' else 'info'
            message = ''
            message += '<b class="badge badge-flexible linter-highlight level">' +issue.level + '</b> '
            message += '<b class="badge badge-flexible linter-highlight ' + issue.state.toLowerCase() + '">' +  issue.predicateType + '</b> '

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


        for dir in atom.project.getDirectories()
            @_log(" -- dir", dir.getBaseName())

        return messages


    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')

module.exports = KtAdvanceScanner
