define ['cs!widget'], (Widget) ->

    class OrderByWidget extends Widget
        subscribed_channels: ['/filters']
        template_name: 'templates/order-by.hjs'

        params_defaults:
            options: 'data-params'
            directionality: 'data-params'
            filter_key: 'data-params'
            default_value: 'data-params'

        params_required: ['options']

        events:
            "change select.order-by-options": "clickOption"

        clickOption: (event) =>
            ###
                Whenever an user clicks a sorting option, notify all other
                interested parties that a new sort order is in place.
            ###
            selected_index = event.currentTarget.selectedIndex
            selected_option = event.currentTarget.options[selected_index]
            @modifyChannel('/filters', {order_by: selected_option.value})

        get_filters: (params) =>
            ###
                When filters arrive, render all the options passed,
                and keep into account the directionality (enabled/disabled).
            ###
            new_options = []
            # If we have directionality enabled
            if @directionality
                dirs =
                    '+': 'ASC'
                    '-': 'DESC'
                for k,v of @options
                    for d in ['+', '-']
                        new_options.push({name: k + ' ' + dirs[d], value: v + d})
            # No directionality
            else
                for k,v of @options
                    new_options.push({name: k, value: v})

            @renderLayout({options: new_options}, false)
            order_by = params.model.get('order_by')
            if order_by
                selector = 'select.order-by-options option[value="'
                selector = selector + order_by
                selector = selector + '"]"'
                @view.$el.find(selector).attr('selected', 'selected')

    return OrderByWidget