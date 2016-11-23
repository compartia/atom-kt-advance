{View} = require 'space-pen'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
    class StatsElement extends ScrollView


        @content: ->
            @div class: 'kt-stats', =>
                @h4 "KT-Advance Stats"
                @h6 outlet: 'file_title'

                @h5 "Primary Proof Obligations"
                @div class: 'metric', =>
                    @div class: 'label', "violations"
                    @div class: 'value main', outlet: 'kt_ppo_violation', ''
                    @div class: 'value', outlet: 'kt_ppo_violation_pc', ''
                @div class: 'metric', =>
                    @div class: 'label', "open"
                    @div class: 'value main', outlet: 'kt_ppo_open', ''
                    @div class: 'value', outlet: 'kt_ppo_open_pc', ''
                @div class: 'metric', =>
                    @div class: 'label', "discharged"
                    @div class: 'value main', outlet: 'kt_ppo_discharged', ''
                    @div class: 'value', outlet: 'kt_ppo_discharged_pc', ''


                @h5 "Secondary Proof Obligations"
                @div class: 'metric', =>
                    @div class: 'label', "violations"
                    @div class: 'value main', outlet: 'kt_spo_violation', ''
                    @div class: 'value', outlet: 'kt_spo_violation_pc', ''
                @div class: 'metric', =>
                    @div class: 'label', "open"
                    @div class: 'value main', outlet: 'kt_spo_open', ''
                    @div class: 'value', outlet: 'kt_spo_open_pc', ''
                @div class: 'metric', =>
                    @div class: 'label', "discharged"
                    @div class: 'value main', outlet: 'kt_spo_discharged', ''
                    @div class: 'value', outlet: 'kt_spo_discharged_pc', ''

                @h5 "Complexity"
                @h6 "Total"
                @div class: 'metric', =>
                    @div class: 'label', "P-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_p', ''
                @div class: 'metric', =>
                    @div class: 'label', "С-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_c', ''
                @div class: 'metric', =>
                    @div class: 'label', "G-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_g', ''


                @h6 "Average Per Line"
                @div class: 'metric', =>
                    @div class: 'label', "P-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_p_pl', ''
                @div class: 'metric', =>
                    @div class: 'label', "С-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_c_pl', ''
                @div class: 'metric', =>
                    @div class: 'label', "G-Complexity"
                    @div class: 'value', outlet: 'kt_ppo_complexity_g_pl', ''

                @h6 "Average Per Proof Obligation"
                @div class: 'metric', =>
                    @div class: 'label', "P-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_p_pp', ''
                @div class: 'metric', =>
                    @div class: 'label', "С-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_c_pp', ''
                @div class: 'metric', =>
                    @div class: 'label', "G-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_g_pp', ''

                #
                @h5 "General"
                @div class: 'metric', =>
                    @div class: 'label', "Number of lines"
                    @div class: 'value main', outlet: 'line_count', ''


        initialize: ->
            console.log 'init'

        _round: (x)->
            return Math.round(x) if x?
            return '-'

        _percent: (x)->
            return Math.round(x * 10.0) / 10.0 +'% ' if x?
            return '-'

        _div: (a, b)->
            if !b?
                return '?'
            if !a?
                return '-'

            return Math.round(100.0*a/b)/100


        update: (filename)->
            return if not @model? or not @model.measures

            m = @model.measures


            if !m.kt_spo_?
                m.kt_spo_=0
            if !m.kt_ppo_?
                m.kt_ppo_=0

            m.po_count = @_round(m.kt_ppo_) + @_round(m.kt_spo_)

            @file_title.text(@model.file_title)
            @line_count.text(@_round(m.line_count))

            @kt_ppo_open.text(@_round(m.kt_ppo_open))
            @kt_ppo_discharged.text(@_round(m.kt_ppo_discharged))
            @kt_ppo_violation.text(@_round(m.kt_ppo_violation))

            @kt_ppo_open_pc.text(@_percent(m.kt_ppo_open_pc))
            @kt_ppo_discharged_pc.text(@_percent(m.kt_ppo_discharged_pc))
            @kt_ppo_violation_pc.text(@_percent(m.kt_ppo_violation_pc))

            @kt_spo_open.text(@_round(m.kt_spo_open))
            @kt_spo_discharged.text(@_round(m.kt_spo_discharged))
            @kt_spo_violation.text(@_round(m.kt_spo_violation))

            @kt_spo_open_pc.text(@_percent(m.kt_spo_open_pc))
            @kt_spo_discharged_pc.text(@_percent(m.kt_spo_discharged_pc))
            @kt_spo_violation_pc.text(@_percent(m.kt_spo_violation_pc))


            @kt_ppo_complexity_p.text(@_round(m.kt_ppo_complexity_p))
            @kt_ppo_complexity_c.text(@_round(m.kt_ppo_complexity_c))
            @kt_ppo_complexity_g.text(@_round(m.kt_ppo_complexity_g))


            @kt_ppo_complexity_p_pl.text(@_div(m.kt_ppo_complexity_p, m.line_count))
            @kt_ppo_complexity_c_pl.text(@_div(m.kt_ppo_complexity_c, m.line_count))
            @kt_ppo_complexity_g_pl.text(@_div(m.kt_ppo_complexity_g, m.line_count))

            @kt_ppo_complexity_p_pp.text(@_div(m.kt_ppo_complexity_p, m.po_count))
            @kt_ppo_complexity_c_pp.text(@_div(m.kt_ppo_complexity_c, m.po_count))
            @kt_ppo_complexity_g_pp.text(@_div(m.kt_ppo_complexity_g, m.po_count))

            #
            @kt_ppo_violation.toggleClass("text-error", m.kt_ppo_violation>0)
            @kt_ppo_violation_pc.toggleClass("text-error", m.kt_ppo_violation>0)
            @kt_spo_violation.toggleClass("text-error", m.kt_spo_violation>0)
            @kt_spo_violation_pc.toggleClass("text-error", m.kt_spo_violation>0)


            @kt_ppo_open.toggleClass("text-warning", m.kt_ppo_open>0)
            @kt_ppo_open_pc.toggleClass("text-warning", m.kt_ppo_open>0)
            @kt_spo_open.toggleClass("text-warning", m.kt_spo_open>0)
            @kt_spo_open_pc.toggleClass("text-warning", m.kt_spo_open>0)



        attached: ->
            # @update()

        getModel: -> @model


        setModel: (@model) ->
            @model
