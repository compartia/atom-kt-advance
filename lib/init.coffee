KtAdvanceScanner = require './kt-advance-scanner'

{Directory, CompositeDisposable} = require 'atom'

module.exports =

    config:
        javaPath:
            default: 'java'
            title: 'Full path to the java executable'
            type: 'string'
        verboseLogging:
            default: false
            title: 'Verbose logging'
            type: 'boolean'

    deactivate: ->
        @subscriptions.dispose()

    activate: (state) ->

        # state-object as preparation for user-notifications
        @state = if state then state or {}
        @scanner = new KtAdvanceScanner()

        @_log("activate")
        # require('atom-package-deps').install('atom-linter')
        @_log("activate install")

        # require('atom-package-deps').install('atom-kt-advance')
        @subscriptions = new CompositeDisposable
        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.javaPath',
                (newValue) => (
                    @javaExecutablePath = newValue.trim()
                    @_log('javaExecutablePath has changed', @javaExecutablePath)
                )

        )

        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.verboseLogging',
                (newValue) =>
                    @verboseLogging = (newValue == true)
        )

        @subscriptions.add(
            atom.workspace.observeTextEditors (textEditor) => (
                console.log 'scanning: ' + textEditor.getPath()
                @scanner.scan(textEditor)
            )
        )

    toggle: ->
        @_log('AtomKtAdvance was toggled!')

    consumeLinter: (registry) ->
        @_log 'Trying to register indie linter'
        atom.packages.activate('linter').then =>
            #TODO: this is called twice!!
            registry = atom.packages.getLoadedPackage('linter').mainModule.provideIndie()

            # HACK because of bug in `linter` package
            registry.emit = registry.emitter.emit.bind(registry.emitter)

            linter = registry.register {name: 'KT-Advance'}
            # @pullRequestLinter.setLinter(linter)
            @subscriptions.add(linter)
            @scanner.setLinter(linter)
            @_log 'indie linter registered'
            @_log linter



    provideLinter: ->
        @scanner.mayBeExecJar()
        return @scanner

    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')
