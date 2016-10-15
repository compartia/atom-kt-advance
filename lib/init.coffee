KtAdvanceScanner = require './kt-advance-scanner'
KtEditorsRegistry = require './editors-reg'

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
        @reg = new KtEditorsRegistry(@scanner)

        @_log("activate")

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

        @layersByEditorId={}
        @subscriptions.add(
            atom.workspace.observeTextEditors (textEditor) => (
                console.log 'Scanning: ' + textEditor.getPath()
                @reg.addEditor(textEditor)
                if @scanner.accept textEditor.getPath()
                    @scanner.scan textEditor
            )
        )

        @subscriptions.add(
            atom.workspace.onDidOpen( (event) =>
                @_log 'OPENED: ',  event.uri
                @_log 'OPENED: ',  event.item
                @reg.addEditor(event.item)
                @scanner.scan event.item
            )
        )

    toggle: ->
        @_log('AtomKtAdvance was toggled!')


    consumeLinter: (registry) ->
        @_log 'Attempting to register an indie linter'
        atom.packages.activate('linter').then =>
            module =atom.packages.getLoadedPackage('linter').mainModule
            indieRegistry = module.provideIndie()
            reg = module.provideLinter()
            # console.error reg

            # HACK because of bug in `linter` package
            indieRegistry.emit = registry.emitter.emit.bind(registry.emitter)

            linter = indieRegistry.register {name: 'KT-Advance'}
            # @pullRequestLinter.setLinter(linter)
            @subscriptions.add(linter)
            @scanner.setLinter(linter)
            @scanner.setRegistry(reg)

            @_log 'indie linter registered'


    provideLinter: -> @scanner


    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')
