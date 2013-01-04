define ['cs!widget'], (Widget) ->

    class ItemCountWidget extends Widget
        template_name: 'templates/item-count.hjs'

        params_defaults:
            single_item: 'data-params'
            multiple_items: 'data-params'
            path: 'data-params'
            value: 'data-params'
            collection: 'data-params'
            icon: 'data-params'
            id: 'data-params'
            color: 'data-params' # used to give a color to the text
            text_first: 'data-params' # in some cases the text needs to go before the number
            suffix: 'data-params' # show somethingafter the number, like % sign
            prefix: 'data-params' # put something before the number, like a + sign
            max_value: 'data-params' # if the number is greater than max_value, display max_value

        params_required: ['single_item', 'multiple_items', 'path']

        post_render:
            tooltip:
                placement: 'right'

        initialize: =>
            # If the value to be displayed is received in data-params,
            # render the layout with this value and the other options
            # and ignore the channels.
            # This fixed was made because sometimes the location percentages
            # were not shown

            if @value?
                @render(@value)
            else
                # Subscribe the widget to /count channel
                @subscribed_channels = ['/count']
                @loading_channels = ['/count']

        changeState: (state, params...) ->
            super(state, params...)
            if state in ['init', 'empty']
                @renderLayout(@getStateTemplateVars(params...))

        loadingStart: () ->
            Utils.notify(Constants.ANALYTICS_LOADING_NOTIFICATION, 'loading')
            @view.$el.addClass('loading-widget')

        loadingEnd: () ->
            Utils.notify(null, 'loading')
            @view.$el.removeClass('loading-widget')

        get_count: (params) =>
            ###
                Whenever a new mention count arrives, display it.
            ###
            if params.type == 'change' or params.type == 'reset' or params.type == 'remove' or params.type == 'add'

                # Just in case nothing is filled in to avoid displaying undefined or undefineds
                @single_item = @single_item ? ''
                # TODO: Multiple values should be automatically generated for
                # direct values as well (when sending `value` as throuh data-params)
                @multiple_items = @multiple_items ? (if @single_item? and @single_item isnt '' then  @single_item + 's' else '' )
                item_count = @extractCountFromParams(params)

                @render(item_count)

        render: (item_count) =>
            # Avoid showing +0 or -0 if the prefix is a + or - sign
            @prefix = if (@prefix in ['+', '-'] and item_count is 0) then null else @prefix

            # Determine if item_count is greater than max_value
            item_count = @max_value if @max_value? and item_count > @max_value
            estimated_item_count = Utils.human_count item_count
            show_tooltip = +item_count isnt +estimated_item_count

            @renderLayout
                state: 'available'
                count: item_count
                items: if item_count == 1 then @single_item else @multiple_items
                icon: @icon
                id: @id
                style: if @color? then " style=color:#{@color}; "
                text_first: @text_first
                suffix: if @suffix? then @suffix
                prefix: if @prefix? then @prefix
                show_real_value: show_tooltip

        isChannelDataEmpty: (event) ->
            ###
                Describes the condition for this widget
                to be in an "EMPTY" (no data state). It's a condition
                applied to the data on it's subscribed channels,
                in this case the /count channel. If the condition is
                met the empty state of the widget is triggered (if it
                exists).

                @return {boolean} True if the extracted count is 0
            ###
            count = @extractCountFromParams(event)
            return count is 0 or count is null

        extractCountFromParams: (params = {}) ->
            ###
                This widget supports counts coming in from
                various datasources: the collection length,
                a data path in an analytics call or a specified
                value. Use this method to extract the value from
                the incoming params
            ###
            if @collection
                return params.collection.length
            if @path
                return params.model.get(@path)
            # This is useful only when the path is hard to get
            if @value
                return @value
            return 0

    return ItemCountWidget