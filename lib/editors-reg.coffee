Logger = require './logger'
KtAdvanceMarkersLayer = require './markers-layer'
{CompositeDisposable} = require 'atom'

class KtEditorsRegistry

    editorById:{}
    layersByEditorId:{}

    #default interval between click on issue highligh and pop-up rendering
    bubbleInterval: 250

    constructor:() ->
        @subscriptions = new CompositeDisposable()
        @subscriptions.add(
            atom.config.observe 'linter.inlineTooltipInterval',
                (newValue) =>
                    if newValue
                        #double it to update popup after DOM is ready
                        @bubbleInterval = parseInt(newValue) * 2
        )


    setScanner: (_scanner) ->
        @scanner = _scanner

    addEditor:(editor) ->
        if @scanner.accept (editor.getPath())
            if @editorById[editor.id] != editor
                @editorById[editor.id]=editor
                @getOrMakeMarkersLayer(editor)
                @_addListeners(editor)


    _addListeners: (editor)->
        #run indie linter on save
        editor.onDidSave (event) =>
            Logger.log 'saved!', editor.id
            @scanner.scan(editor)

        ##
        # listen to Bubble. When bubble is up, update DOM after some timeout
        # TODO : this is a dirty hack
        editor.onDidAddDecoration (decoration) =>
            if decoration.properties.type=='overlay'
                el = decoration.properties.item
                if el? and el.querySelector?
                    setTimeout( =>
                        @layersByEditorId[editor.id]?.updateAssumptionsLinks(el)
                    , @bubbleInterval)


    getOrMakeMarkersLayer: (textEditor) ->
        # @_log 'creating marker layer for editor id '+ textEditor.id, '....'
        if not @layersByEditorId[textEditor.id]?
            @layersByEditorId[textEditor.id] = new KtAdvanceMarkersLayer(textEditor)
            Logger.log 'created marker layer for editor id ', textEditor.id
        return @layersByEditorId[textEditor.id]


module.exports = KtEditorsRegistry
