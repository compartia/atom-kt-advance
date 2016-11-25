# Logger = require './logger'
{CompositeDisposable,Emitter} = require 'atom'

StatsElement = require './stats-view'
StatsModel =  require('./stats-model')

module.exports =

    config:
        javaPath:
            default: 'java'
            title: 'Full path to the java executable'
            type: 'string'

        violationsOnly:
            default: true
            title: 'Show proven violations only'
            description: 'Do not display Open Proof Obligations (PPOs). The number of PPOs could be huge for large projects'
            type: 'boolean'



    maybeScan:(textEditor) ->

        if textEditor.getPath? and @scanner.accept textEditor.getPath()
            @reg.addEditor(textEditor)
            @scanner.scan textEditor
        else
            @model.file_key = null
            @view.update()



    deactivate: ->
        @subscriptions.dispose()

    activate: (state) ->
        StatsElement ?= require './stats-view'

        @view = new StatsElement
        @model = new StatsModel

        @view.setModel @model
        panel = atom.workspace.addRightPanel item: @view


        KtAdvanceScanner = require './scanner'
        KtEditorsRegistry = require './editors-reg'

        # state-object as preparation for user-notifications
        @state = if state then state or {}
        @reg = new KtEditorsRegistry()
        @scanner = new KtAdvanceScanner(@reg)
        @scanner.setStatsModel(@model)
        @scanner.setStatsView(@view)

        @reg.setScanner(@scanner)

        @queue = []


        @subscriptions = new CompositeDisposable

        @subscriptions.add(
            atom.config.observe 'atom-kt-advance.verboseLogging',
                (newValue) =>
                    @verboseLogging = (newValue == true)
        )

        @subscriptions.add(
            atom.workspace.onDidStopChangingActivePaneItem (textEditor) => (
                @maybeScan textEditor
            )
        )

        console.log 'activated'



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
                # console.log 'indie linter is ready'
                @scanner.setLinter(linter)
                # console.log atom.textEditors.editors
                atom.textEditors.editors.forEach (textEditor) =>
                    # console.log 'currently open: '+textEditor.getPath()
                    @maybeScan textEditor
