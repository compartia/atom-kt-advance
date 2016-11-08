# Logger = require './logger'
{CompositeDisposable,Emitter} = require 'atom'

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

    maybeScan:(textEditor) ->
       if @scanner.accept textEditor.getPath()
           @reg.addEditor(textEditor)
           @scanner.scan textEditor

    deactivate: ->
        @subscriptions.dispose()

    activate: (state) ->

        KtAdvanceScanner = require './scanner'
        KtEditorsRegistry = require './editors-reg'

        # state-object as preparation for user-notifications
        @state = if state then state or {}

        @reg = new KtEditorsRegistry()

        @scanner = new KtAdvanceScanner(@reg)
        @reg.setScanner(@scanner)

        @queue = []
        console.log 'activate'

        @subscriptions = new CompositeDisposable
        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.javaPath',
                (newValue) => (
                    @javaExecutablePath = newValue.trim()
                    console.log 'javaExecutablePath has changed:' + @javaExecutablePath
                )

        )

        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.verboseLogging',
                (newValue) =>
                    @verboseLogging = (newValue == true)
        )

        @subscriptions.add(
            atom.workspace.observeTextEditors (textEditor) => (
                @maybeScan textEditor
            )
        )


    toggle: ->
        console.log('AtomKtAdvance was toggled!')


    provideLinter: -> @scanner

    consumeLinter: (registry) ->
        console.log 'Attempting to register an indie linter'
        atom.packages.activate('linter').then =>
            module =atom.packages.getLoadedPackage('linter').mainModule
            indieRegistry = module.provideIndie()
            reg = module.provideLinter()

            # HACK because of bug in `linter` package
            indieRegistry.emit = registry.emitter.emit.bind(registry.emitter)

            linter = indieRegistry.register {name: 'KT-Advance'}
            # @pullRequestLinter.setLinter(linter)
            @subscriptions.add(linter)


            Promise.resolve(linter).then (value) =>
                console.log 'indie linter is ready'
                @scanner.setLinter(linter)
                # console.log atom.textEditors.editors
                atom.textEditors.editors.forEach (textEditor) =>
                    console.log 'currently open: '+textEditor.getPath()
                    @maybeScan textEditor
