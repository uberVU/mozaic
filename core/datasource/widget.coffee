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

            # For each of the data channels the widget is subscribed to
            for channel, real_channel of widget_data.subscribed_channels
                do (channel, real_channel) =>
                    # Subscribe the widget to the events of the channel
                    @_bindWidgetToChannel(channel, real_channel, widget_data)
                    #add reference counter for determining if this channel
                    #is still in use or not
                    collection = channels_utils.getChannelKey(real_channel)
                    @meta_data[collection]['reference_count'] = (@meta_data[collection]['reference_count'] ? 0) + 1
                    #this timestamp allows us to see for how long the channel
                    #has been inactive
                    @meta_data[collection]['time_of_reference_expiry'] = null

        destroyWidget: (widget_data) ->

            logger.warn "Destroy #{widget_data.name} widget in DataSource"
            for fake_channel, channel of widget_data.widget.channel_mapping
                if not (channel of @meta_data)
                    logger.warn('Could not unbind widget from collection ' +
                                 channel + ' because it was already gone')
                    continue

                # Start unbinding the widget to the existing channel.
                widget_method = @_getWidgetMethod(fake_channel, widget_data.widget)
                [collection, item, events] = channels_utils.splitChannel(fake_channel)

                # For relational channel, we have item-level unbinding and
                # collection-level unbinding, depending on the type of widget
                # subscription.
                if @_getType(channel) == 'relational'
                    if item == "all"
                        @data[channel].off(events, widget_method, widget_data.widget)
                    else
                        individual_item = @data[channel].get(item)
                        # Here we might have a problem: when resetting a
                        # collection, there is no way to keep references to the
                        # old widgets so that we unbind events from them.
                        # TODO(andrei): investigate if we can do something in
                        # the BaseModel class.
                        if individual_item
                            individual_item.off(events, widget_method, widget_data.widget)
                else if @_getType(channel) == 'api'
                    @data[channel].off(events, widget_method, widget_data.widget)

                @meta_data[channel]['reference_count'] -= 1
                if @meta_data[channel]['reference_count'] == 0
                    @meta_data[channel]['time_of_reference_expiry'] = (new Date).getTime()

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

            # Return the actual method
            widget[method_name]

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
