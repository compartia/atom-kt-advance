Logger = require './logger'
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


    putMessage: (referenceKey, message) ->
        @messageByKey[referenceKey] = message
        marker = @_markMsgRange (message)
        @messageKeyByMarker[marker.id] = referenceKey
        @markersByReferenceKey[referenceKey] = marker
        return marker

    ### adds a marker and a decoraion to where an assumption points to
    TODO: add a tooltip (overlay) with description
    ###
    markLinkTargetRange: (refKey, range, txt, bundleId) ->
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
            referenceKey = @messageKeyByMarker[marker.id]
            msg = @messageByKey[referenceKey]
            msg.range = marker.getBufferRange()
            # TODO: update linter UI, rendered messages

        @markers.push marker
        return marker

    getMarkerRange: (referenceKey, fallbackRange) ->
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



    # not in use
    # deprecated
    updateLinks: (bundleId) ->

        className='links-'+bundleId
        assumptionLinks = document.getElementsByClassName(className)


        for lnk in assumptionLinks
            @updateAssumptionsLinks(lnk)
            # fileLink={
            #     row:lnk.getAttribute('line')
            #     col:lnk.getAttribute('col')
            #     file:lnk.getAttribute('uri')
            # }
            # lnk.onclick = ()=>
            #     @navigate(markerId, fileLink)

        # TODO write this method

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
        for marker in @markers
            marker.destroy()

        @markers=[]
        @messageByKey={}
        @messageKeyByMarker={}
        @markersByReferenceKey={}

module.exports = KtAdvanceMarkersLayer
