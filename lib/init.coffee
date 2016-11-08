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

    deactivate: ->
        @subscriptions.dispose()

    activate: (state) ->

        KtAdvanceScanner = require './kt-advance-scanner'
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
                if @scanner.accept textEditor.getPath()
                    @reg.addEditor(textEditor)
            )
        )




    toggle: ->
        console.log('AtomKtAdvance was toggled!')


    provideLinter: -> @scanner
