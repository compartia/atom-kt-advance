{BufferedProcess} = require 'atom'
path = require 'path'


class KtAdvanceJarExecutor

    locateJar: ->
        file = atom.packages.resolvePackagePath ('atom-kt-advance')
        if file?
            file = path.join file, 'lib', 'json-kt-advance-5.5.5-jar-with-dependencies.jar'



    execJar:(jsonPath, textEditor) ->
        jarPath = @locateJar()
        userDir = @findRoot(jsonPath)

        command = 'java'
        args = ['-jar', jarPath, userDir, textEditor.getPath()]

        promise = new Promise( (resolve, reject) =>
            exit = (code) ->
                console.log('exited with code ' + code)
                # @parseJson(textEditor, @fs)
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

    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance jar: '
            console.log prefix + msgs.join(' ')

    _warn: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance jar: '
            console.warn prefix + msgs.join(' ')

module.exports = KtAdvanceJarExecutor
