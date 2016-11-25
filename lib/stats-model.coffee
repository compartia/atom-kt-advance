
module.exports =
class StatsModel
    measuresByFile:{}
    # measures: {}
    projectMeasures:{}

    getMeasures: (file)=>
        if file?
            return @measuresByFile[file]
        else
            return @projectMeasures

    setMeasures: (file, _measures)=>
        @measuresByFile[file]=_measures
        @updateSum()

    deleteMeasures: (file)=>
        delete @measuresByFile[file]
        @updateSum()

    getProjectMeasures: ()->
        return @projectMeasures

    updateSum: ()->
        @projectMeasures=
            kt_ppo_ :0
            kt_spo_: 0
            line_count: 0

            kt_ppo_open: 0
            kt_ppo_discharged: 0
            kt_ppo_violation: 0

            kt_spo_open: 0
            kt_spo_discharged: 0
            kt_spo_violation: 0

            kt_ppo_complexity_p: 0
            kt_ppo_complexity_c: 0
            kt_ppo_complexity_g: 0

        for file, m of @measuresByFile
            for metricName, val of m
                if @projectMeasures[metricName]?
                    @projectMeasures[metricName]+=parseFloat(val)
                else
                    @projectMeasures[metricName]=parseFloat(val)

        @projectMeasures.file_title="Project"
