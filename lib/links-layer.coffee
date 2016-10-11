
class KtAdvanceColorLayer

    constructor: (editor) ->
        @editor=editor
        @markers=[]
        @_addMarkerLayer(editor)


    _addMarkerLayer: (textEditor) ->
        if textEditor.addMarkerLayer?
            @markerLayer = textEditor.addMarkerLayer()
        else 
            @markerLayer = textEditor

    markBufferRange: (range) ->
        marker = @markerLayer.markBufferRange(range)
        decorationParams = {
            type: 'highlight'
            class: 'kt-assumption'
            includeMarkerText: true
        }
        decoration = @editor.decorateMarker(marker, decorationParams)
        @markers.push marker
        return decoration

    removeAllMarkers: () ->
        for marker in @markers
            marker.destroy()

        @markers=[]

module.exports = KtAdvanceColorLayer
