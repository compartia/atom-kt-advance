module.exports = Logger =
    log: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance scanner: '
            console.log prefix + msgs.join(' ')

    error: (msgs...) ->
        if (msgs.length > 0)
            prefix = 'kt-advance scanner: '
            console.error prefix + msgs.join(' ')
