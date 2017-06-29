{Complexitiy} = require 'xml-kt-advance/lib/model/po_node'

module.exports =
class StatsModel
    file_key: ''
    measuresByFile:{}

    getMeasures: (file_key) =>
        if file_key?
            m = @measuresByFile[file_key]
            if m?
                return m
            else
                m = {}
                @measuresByFile[file_key]=m
                return m
        else
            return {}

    setMeasures: (file, _measures)=>
        @measuresByFile[file]=_measures

    deleteMeasures: (file)=>
        # XXX: do not delete it!
        delete @measuresByFile[file]

    _level:(po) =>
        if po.level == "primary"
            return  "ppo"
        return "spo"

    
    _state:(po) =>
        return po.stateName

    _incKey:(measures, key, inc=1) =>
        if !measures[key]
            measures[key] = 0
        measures[key] = measures[key]+inc

    build: (proofObligations, projectPath) =>
        @measuresByFile = {}

        pMetrics = @getMeasures(projectPath)
        @file_key = projectPath
        for po in proofObligations

            m = @getMeasures(po.file);

            key = "kt_"
            key = key + @_level(po) + "_"

            @_incKey(m, key)
            @_incKey(pMetrics, key)

            key = key + @_state(po)
            @_incKey(m, key)
            @_incKey(pMetrics, key)

            for c in [0..2]
                key='kt_' + @_level(po) + '_complexity_' + Complexitiy[c].toLowerCase()
                @_incKey(m, key, po.complexity[c])
                @_incKey(pMetrics, key, po.complexity[c])

        return
