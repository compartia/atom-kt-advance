{View} = require 'space-pen'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
    class StatsElement extends ScrollView


        @content: ->
            @div class: 'kt-stats', =>
                @h4 "KT-Advance Stats"


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

                @h5 "Complexity (sum)"
                @div class: 'metric', =>
                    @div class: 'label', "P-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_p', ''
                @div class: 'metric', =>
                    @div class: 'label', "С-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_c', ''
                @div class: 'metric', =>
                    @div class: 'label', "G-Complexity"
                    @div class: 'value main', outlet: 'kt_ppo_complexity_g', ''

        initialize: ->
            console.log 'init'

        _round: (x)->
            return Math.round(x) if x?
            return '-'

        _percent: (x)->
            return Math.round(x*10)/10 +' % ' if x?
            return '-'

        update: (filename)->
            return if not @model? or not @model.measures

            m = @model.measures
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



            # "measures" : {
            #   "kt_spo_violation" : "0.0",
            #   "kt_spo_violation_pc" : "0.0",
            #   "kt_ppo_open_predicate_non_negative" : "9.0",
            #   "kt_per_predicate_distr" : "[{\"key\":\"predicate_cast\",\"value\":[1.0,0.0,0.0,0.0]},{\"key\":\"predicate_non_negative\",\"value\":[9.0,2.0,0.0,0.0]},{\"key\":\"predicate_unsigned_to_signed_cast\",\"value\":[2.0,0.0,0.0,0.0]},{\"key\":\"predicate_width_overflow\",\"value\":[9.0,0.0,0.0,0.0]}]",
            #   "kt_ppo_violation" : "2.0",
            #   "kt_ppo_violation_pc" : "1.1695906432748537",
            #   "kt_spo_open_pc" : "0.0",
            #   "kt_ppo_open" : "21.0",
            #   "kt_ppo_complexity_p" : "86.0",
            #   "kt_spo_discharged_pc" : "0.0",
            #   "kt_ppo_open_predicate_width_overflow" : "9.0",
            #   "kt_ppo_discharged_pc" : "86.54970760233918",
            #   "kt_spo_open" : "0.0",
            #   "kt_spo_discharged" : "0.0",
            #   "kt_ppo_complexity_g" : "0.0",
            #   "kt_ppo_discharged" : "148.0",
            #   "kt_ppo_complexity_c" : "34.0",
            #   "kt_ppo_" : "171.0",
            #   "kt_ppo_open_pc" : "12.280701754385966",
            #   "kt_spo_" : "0.0"
            # }

        attached: ->
            # @update()

        getModel: -> @model



        setModel: (@model) ->
            @model
