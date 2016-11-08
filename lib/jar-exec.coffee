{BufferedProcess, CompositeDisposable} = require 'atom'
path = require 'path'

VERSION = "5.5.6"


class KtAdvanceJarExecutor
    javaExecutablePath: ''
    constructor: ->

        @subscriptions = new CompositeDisposable
        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.javaPath',
                (newValue) => (
                    @javaExecutablePath = newValue.trim()
                    console.log 'javaExecutablePath has changed:' + @javaExecutablePath
                )

        )

    locateJar: ->
        file = atom.packages.resolvePackagePath ('atom-kt-advance')
        if file?
            file = path.join file, 'lib', 'json-kt-advance-'+VERSION+'-jar-with-dependencies.jar'



    execJar:(jsonPath, textEditor) ->
        jarPath = @locateJar()
        userDir = @findRoot(jsonPath)

        console.log  'running: ' + userDir + ' json:' + jsonPath

        command = @javaExecutablePath
        args = ['-jar', jarPath, userDir, textEditor.getPath()]


        promise = new Promise( (resolve, reject) =>
            exit = (code) ->
                console.log('exited with code ' + code)
                if code==0
                    resolve()
                else
                    reject()

            process = new BufferedProcess({command, args, @stdout, exit})
        )

    findRoot:(filePath) ->
        for root in atom.project.getPaths()
            relative = path.relative(root, filePath)
            joined = root + path.sep + relative
            if joined == filePath
                return root
        return false

    stdout: (outputChunk) ->
        outputLines=outputChunk.split('\n')
        for output in outputLines
            if output.startsWith('ERROR')
                console.error (output)
            else if output.startsWith('WARN')
                console.warn (output)
            else
                console.log (output)

module.exports = {KtAdvanceJarExecutor,VERSION}
