define ['cs!widget'], (Widget) ->

    class OrderByWidget extends Widget
        subscribed_channels: ['/filters']
        template_name: 'templates/order-by.hjs'

        params_defaults:
            options: 'data-params'
            directionality: 'data-params'
            filter_key: 'data-params'
            default_value: 'data-params'

        DIRECTIONS:
            'asc': 'ASC'
            'desc': 'DESC'

        params_required: ['options']

        events:
            "click .order-by-options a": "clickOption"

        clickOption: (event) =>
            ###
                Whenever an user clicks a sorting option, notify all other
                interested parties that a new sort order is in place.
            ###
            selected_order_by = $(event.currentTarget).data('value')
            [sort, order] = _.string.words(selected_order_by, ' ')

            # Prepare also the sort_by filter
            # used by tastypie resources
            desc_key = _.last _.keys(@DIRECTIONS)
            sort_by = if order is desc_key then "-#{sort}" else "#{sort}"

            @modifyChannel('/filters',
                sort: sort
                order: order
                sort_by: sort_by
            )

            # It was a click on a link so this prevents default
            return false

        get_filters: (params) =>
            ###
                When filters arrive, render all the options passed,
                and keep into account the directionality (enabled/disabled).
            ###
            sort_options = []
            for sort_name, order of @options
                order_direction = _.last(_.string.words(order, ' '))
                order_with_direction = _.has(@DIRECTIONS, order_direction)

                # If a default directions is specified in options (e.g. published+)
                # then do not insert both ASC and DESC for this field
                if order_with_direction or not @directionality
                    sort_options.push(
                        name: sort_name,
                        value: order)
                else
                    sort_options.push(
                        name: "#{sort_name} #{@DIRECTIONS[dir]}"
                        value: "#{order} #{dir}") for dir in _.keys(@DIRECTIONS)

            @renderLayout({options: sort_options}, false)

            # Visually set the selected order_by param
            order_by = "#{params.model.get('sort')} #{params.model.get('order')}"
            if order_by
                selected_order_by = _.find(sort_options, (option) -> option.value is order_by)
                @view.$el.find('.top-sort-container .dropdown-toggle span').text(selected_order_by.name) if selected_order_by

    return OrderByWidget
