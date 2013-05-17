define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceWidgetMixin
        ###
            Includes methods for widgets to subscribe to data channels and
            new and delete methods once widgets "connect to data"
        ###

        newWidget: (widget_data) ->
            ###
                This gets called whenever a new widget announces its existence.

                It determines which data from the data source is "interesting"
                for the widget and subscribes the widget to changes on that data.
            ###
            logger.info "Initializing #{widget_data.name} widget in DataSource"

            @increaseReferenceCountsForChannelsOfNewWidget(widget_data.widget)

            # Only bind widget to data of channels it has subscribed to
            for reference, translated of widget_data.subscribed_channels
                channel_key = channels_utils.getChannelKey(translated)
                unless @reference_data[channel_key]?
                    logger.warn("Couldn't bind widget to channel #{channel_key} " +
                                "because it was already removed")
                    continue
                # Subscribe the widget to the events of the channel
                @_bindWidgetToChannel(reference, translated, widget_data)

        _getWidgetMethod: (fake_channel, widget) ->
            ###
                Gets the appropriate function from the widget to be called
                whenever events on channel occur.

                channel: the channel on which events occur
                widget: a widget instance
                Returns: an actual function from the widget instance
            ###

            # Get the channel key. This is where the actual data is in @data
            channel_key = channels_utils.getChannelKey(fake_channel)

            # Get the method name
            method_name = channels_utils.widgetMethodForChannel(widget, channel_key)

            # Wrap callback in order to make sure that the we're always calling
            # the current method for a given key on the widget, since members
            # of a class instance can be overridden dynamically at any point in
            # JavaScript
            if _.isFunction(widget[method_name])
                return -> widget[method_name](arguments...)
            null

        _bindWidgetToRelationalChannel: (fake_channel, channel, widget_data) ->
            ###
                Given a widget, bind it to the events of a backbone collection
                or of an individual item of the collection.
            ###

            # Determine the method to be called on the widget
            [collection, item, events] = channels_utils.splitChannel(channel)
            collection = '/' + collection
            widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
            if not widget_method
                return

            # Whole collection and also give the widget context
            if item == "all"
                @data[collection].on(events, widget_method, widget_data.widget)
                # If data is already there, just pretend it arrived just now.
                # but only if a fetch from server is not in progress
                # otherwise a unwanted list refresh will be triggered
                if @meta_data[collection].last_fetch? and
                (not @meta_data[collection].waiting_fetches? or @meta_data[collection].waiting_fetches is 0)
                    widget_method('reset', @data[collection])
            # Individual collection models
            else
                individual_model = @data[collection].get(item)
                # If model is already there, we just bind it and get over with it
                if individual_model
                    individual_model.on(events, widget_method, widget_data.widget)
                    widget_method('change', individual_model)
                # Else, enqueue the (individual model ID, widget) pair and keep
                # checking for new items whenever data arrives into this channel.
                # When the model finally arrives, drop the reference to the widget.
                else
                    if not ('delayed_single_items' of @meta_data[collection])
                        @meta_data[collection]['delayed_single_items'] = []
                    @meta_data[collection]['delayed_single_items'].push(
                        fake_channel: fake_channel
                        channel: channel
                        widget_data: widget_data
                        id: item
                    )

        _bindWidgetToApiChannel: (fake_channel, channel, widget_data) ->
            ###
                Given a widget, bind it to the events of an api (raw data) channel.
            ###
            [collection, item, events] = channels_utils.splitChannel(channel)
            collection = '/' + collection
            widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
            if not widget_method
                return

            raw_channel = @data[collection]
            raw_channel.on(events, widget_method, widget_data.widget)

            # If data is already there, just pretend it arrived just now.
            if @meta_data[collection].last_fetch
                widget_method('change', @data[collection])

        _bindWidgetToChannel: (fake_channel, channel, widget_data) ->
            ###
                Bind a widget to a given channel's events.

                This is the __only__ place in which the datalayer should use
                the widget reference. The reason for which we need the reference
                here is that it subscribes it to the events of the private data
                of the datasource.

                This will actually delegate to more specific types of bindings:
                    - bindings of widgets to backbone collections
                        (for relational channels)
                    - bindings of widgets to raw data
                        (for api channels)
            ###
            logger.info "Linking widget #{widget_data.name} to #{channel}"
            resource_type = @_getType(channel)
            if resource_type == 'relational'
                @_bindWidgetToRelationalChannel(fake_channel, channel, widget_data)
            else if resource_type == 'api'
                @_bindWidgetToApiChannel(fake_channel, channel, widget_data)
