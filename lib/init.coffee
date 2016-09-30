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


    _log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance: '
            console.log prefix + msgs.join(' ')


    toggle: ->
        @_log('AtomKtAdvance was toggled!')


    provideLinter: ->
        fs = require 'fs'
        @scanner = new KtAdvanceScanner(fs)
        @scanner.mayBeExecJar()
        return @scanner
