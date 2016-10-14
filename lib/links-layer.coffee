
class KtAdvanceColorLayer

    constructor: (editor) ->
        @editor=editor
        @markers=[]
        @_addMarkerLayer(editor)


    getMarker: (markerId) ->
        @markerLayer?.getMarker(markerId)

    _addMarkerLayer: (textEditor) ->
        if textEditor.addMarkerLayer?
            @markerLayer = textEditor.addMarkerLayer()
        else
            @markerLayer = textEditor

    navigate:(markerId, fileLink)->
        options = {
            initialLine: parseInt(fileLink.row)
            initialColumn: parseInt(fileLink.col)
        }
        atom.workspace.open(fileLink.file, options)


    updateLinks: (markerId) ->
        className='kt-assumption-'+markerId
        assumptionLinks = document.getElementsByClassName(className)
        for lnk in assumptionLinks
            fileLink={
                row:lnk.getAttribute('line')
                col:lnk.getAttribute('col')
                file:lnk.getAttribute('uri')
            }
            lnk.onclick = ()=>
                @navigate(markerId, fileLink)

        # TODO write this method

    makeAssumptionDescr: (message)->
        el = document.createElement('linter-message')
        el.textContent = message
        el.className = 'kt-assumption'
        return el

    markBufferRange: (range, message) ->
        marker = @markerLayer.markBufferRange(range)
        marker.onDidChange (event) =>
            @updateLinks(marker.id)


        decorationParams = {
            type: 'highlight'
            # type: 'overlay'
            class: 'kt-assumption'
            includeMarkerText: true
            # item: @makeAssumptionDescr(message)
        }
        decoration = @editor.decorateMarker(marker, decorationParams)
        @markers.push marker

        return decoration

    removeAllMarkers: () ->
        for marker in @markers
            marker.destroy()

        @markers=[]

module.exports = KtAdvanceColorLayer
