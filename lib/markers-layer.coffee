Htmler = require './html-helper'

### Manages per-editor message markers and decorations ###
class KtAdvanceMarkersLayer

    markerLayer:null


    constructor: (editor) ->
        @editor=editor
        @markers=[]
        @messageByKey={}
        @messageKeyByMarker={}
        @markersByReferenceKey={}
        @_addMarkerLayer(editor)


    putMessage: (key, message) ->
        @messageByKey[key] = message
        marker = @_markMsgRange (message)
        @messageKeyByMarker[marker.id] = key
        @markersByReferenceKey[key] = marker
        return marker

    ### adds a marker and a decoraion to where an assumption points to
    TODO: add a tooltip (overlay) with description
    ###
    markLinkTargetRange: (refKey, range, txt, bundleId) ->
        # console.error 'markLinkTargetRange'
        marker = @markersByReferenceKey[refKey]
        if not marker?
            marker = @markerLayer.markBufferRange(range)
            @markersByReferenceKey[refKey] = marker
            marker.onDidChange (event) =>
                @updateLinks(bundleId)

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
            key = @messageKeyByMarker[marker.id]
            msg = @messageByKey[key]
            msg.range = marker.getBufferRange()
            # TODO: update linter UI, rendered messages

        @markers.push marker
        return marker

    getMarkerRange: (key, fallbackRange) ->
        marker = @markersByReferenceKey[key]

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


    ### called when bubble shown ###
    updateAssumptionsLinks: (el) ->

        Promise.resolve(el).then (value) =>
            links = value.querySelectorAll("#kt-assumption-link-src")
            if links?
                for link in links
                    @_updateAssumptionsLineNumber(link)

        return

    _updateAssumptionsLineNumber:(link)->
        refId = link.getAttribute('data-marker-id') + '-lnk'
        range = @getMarkerRange(refId)

        el= link.querySelector("#kt-location")
        if el
            el.innerHTML = Htmler.rangeToHtml(range)
            file = link.getAttribute('uri')
            link.onclick = () ->
                options = {
                    initialLine: range.start.row
                    initialColumn: range.start.column
                }
                atom.workspace.open file, options

        return el

    ### updating line numbers for the assumptions links ###
    updateLinks: (bundleId) ->
        # console.error  'updateLinks'
        className='links-'+bundleId
        assumptionLinks = document.getElementsByClassName(className)

        for lnk in assumptionLinks
            @updateAssumptionsLinks(lnk)


    navigate:(markerId, fileLink)->
        options = {
            initialLine: parseInt(fileLink.row)
            initialColumn: parseInt(fileLink.col)
        }
        atom.workspace.open(fileLink.file, options)

    makeAssumptionDescr: (message)->
        el = document.createElement('linter-message')
        el.textContent = message
        el.className = 'kt-assumption'
        return el


    removeAllMarkers: () ->
        console.error  'removeAllMarkers'
        for marker in @markers
            marker.destroy()

        @markers=[]
        @messageByKey={}
        @messageKeyByMarker={}
        @markersByReferenceKey={}

module.exports = KtAdvanceMarkersLayer
