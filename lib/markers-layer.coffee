
class KtAdvanceMarkersLayer

    constructor: (editor) ->
        @editor=editor
        @markers=[]
        @messageByKey={}
        @messageKeyByMarker={}
        @markersByReferenceKey={}
        @_addMarkerLayer(editor)


    putMessage: (referenceKey, message)->
        # console.warn "put msg:" + referenceKey
        @messageByKey[referenceKey]=message
        marker = @_markMsgRange (message)
        @messageKeyByMarker[marker.id] = referenceKey
        @markersByReferenceKey[referenceKey] = marker
        return marker

    markLinkTargetRange: (refKey, range, txt) ->
        marker = @markersByReferenceKey[refKey]
        if not marker?
            marker = @markerLayer.markBufferRange(range)
            @markersByReferenceKey[refKey] = marker
            marker.onDidChange (event) =>
                @updateLinks(marker.id)

            decorationParams = {
                type: 'highlight'
                # type: 'overlay'
                class: 'kt-assumption'
                includeMarkerText: true
                # item: @makeAssumptionDescr(txt)
            }
            decoration = @editor.decorateMarker(marker, decorationParams)
            @markers.push marker

        return marker

    _markMsgRange: (message) ->
        marker = @markerLayer.markBufferRange(message.range)

        marker.onDidChange (event) =>
            referenceKey = @messageKeyByMarker[marker.id]
            msg = @messageByKey[referenceKey]
            msg.range = marker.getBufferRange()
            # console.error msg.type+":"+marker.getBufferRange()
            # +":"+msg.range

        @markers.push marker
        return marker

    getMarkerRange: (referenceKey, fallbackRange) ->
        # console.error marker
        marker = @markersByReferenceKey[referenceKey]

        if marker
            return marker.getBufferRange()
        else
            return fallbackRange


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


    # not in use
    # deprecated
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


    removeAllMarkers: () ->
        for marker in @markers
            marker.destroy()

        @markers=[]
        @messageByKey={}
        @messageKeyByMarker={}
        @markersByReferenceKey={}

module.exports = KtAdvanceMarkersLayer
