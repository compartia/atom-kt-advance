
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
                return {}
        else
            return {}

    setMeasures: (file, _measures)=>
        @measuresByFile[file]=_measures

    deleteMeasures: (file)=>
        delete @measuresByFile[file]
