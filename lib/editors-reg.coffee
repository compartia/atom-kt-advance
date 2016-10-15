
class KtEditorsRegistry

    editorById:{}


    constructor: (scanner) ->
        @scanner=scanner


    addEditor:(editor)->
        if @editorById[editor.id] != editor
            @editorById[editor.id]=editor
            @_addListeners(editor)

    _addListeners: (editor)->
        editor.onDidSave (event) =>
            console.log 'saved!' + editor.id
            @scanner.scan(editor)



module.exports = KtEditorsRegistry
