define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceGCMixin
        ###
            Includes a method for garbage collect channels when they
            are no longer used
        ###

        channelCanBeGarbageCollected: (channel) ->
            ###
                Checks if a Datasource channel can be safely garbage collected.

                There are several factors which can influence this:

                - the channel has waiting fetches (aka, we have launched
                  a request to fetch data, and that request will have nowhere
                  to add the data to)

                - the channel hasn't had reference_count 0 for enough time
                  (having a channel lurking around for a little while with
                  data in it is useful when changing from one controller to
                  another - the same channels from the new controller will
                  be cloned from the old ones)

                - the channel is eternal (this is useful if you have info
                  that is displayed on absolutely all pages and don't want
                  it to ever be garbage collection); this should be used
                  in conjunction with application_controller which should
                  be careful to create those eternal channels and pass them
                  on correctly.
            ###
            meta = @meta_data[channel]
            reference = @reference_data[channel]

            # Eternal channels are never expired
            if meta.eternal
                logger.info("Channel #{channel} cannot be garbage " +
                            "collected because it's eternal")
                return false

            # If this channel still has references attached, so skip it.
            unless reference['time_of_reference_expiry']?
                logger.info("Channel #{channel} cannot be garbage " +
                            "collected because it still has widgets " +
                            "referencing it. (reference count: #{reference.reference_count})")
                return false

            # Channels with pending fetches should not be garbage collected
            if 'waiting_fetches' of meta and meta.waiting_fetches > 0
                logger.info("Channel #{channel} cannot be garbage " +
                            "collected because it still has fetches " +
                            "waiting to arrive")
                return false

            expired_for = (new Date).getTime() - reference['time_of_reference_expiry']
            if expired_for <= @checkIntervalForUnusedChannels
                logger.info("Channel #{channel} hasn't lurked around enough. " +
                            "Leaving it right there for now, because maybe " +
                            "someone wants to clone or re-use it.")

            return true

        garbageCollectChannel: (channel) ->
            ###
                Garbage collect a channel after we detect that it's of no use
                to anyone else.
            ####
            # Declare that channel has expired loudly and openly.
            logger.info("Garbage collecting channel #{channel} in DataSource.")
            delete @reference_data[channel]
            # The meta_data might not have even been created if a channel got
            # removed before its collection loaded
            return unless @meta_data[channel]?
            # Stop periodic refresh if it was enabled
            @_stopRefreshing(channel)
            # Throw away channel meta-data
            delete @meta_data[channel]
            # Delete cyclic reference from channel to its buffer
            if @data[channel].buffer?
                delete @data[channel].buffer.collection
                @data[channel].buffer.off()
                delete @data[channel].buffer
            # Unbind all remaining widgets (should be none!)
            @data[channel].off()
            # Throw away reference to the actual data
            delete @data[channel]

        checkForUnusedChannels: ->
            ###
                This function gets cleaned up periodically in order to
                inspect which channels still have a non-zero reference count
                and which don't.

                Those who have been inactive (e.g., 0 reference count) for
                quite a while (> checkIntervalForUnusedChannels) will be
                garbage colllected, unless they are eternal.

                Some collections might be eternal, and this is a per-channel
                flag (so not found in datasource.js, but passed to
                Utils.newDataChannels when creating channel instances) because
                for example they are created from the application controller
                and they should live for the whole navigation session regardless
                of whether what is found on the page actually references them
                or not.
            ###
            for channel of @meta_data
                if @channelCanBeGarbageCollected(channel)
                    @garbageCollectChannel(channel)

        increaseReferenceCountsForChannelsOfNewWidget: (widget) ->
          ###
              Given a newly-appeared widget, increase reference counts for
              channels it references via channel_mapping (the mapping from
              the channels the widget needs to actual channel IDs from the
              Datasource).
          ###
          for reference, key of widget.channel_mapping
                unless @reference_data[key]?
                    logger.warn("Couldn't increase count of #{key} " +
                                "because it was already removed")
                    continue
                # Add reference counter for determining if this channel
                # is still in use or not
                @reference_data[key]['reference_count'] ?= 0
                @reference_data[key]['reference_count'] += 1
                # Store a direct reference to the widget as well, it helps
                # debugging and providing more transparency to the datasource
                @reference_data[key].widgets[widget.params.widget_id] = widget
                # This timestamp allows us to see for how long the channel
                # has been inactive
                @reference_data[key]['time_of_reference_expiry'] = null

        decreaseReferenceCountsForChannelsOfDestroyedWidget: (widget) ->
            ###
                Given a freshly-garbage-collected widget, decrease the reference
                counts of the channels used by the widget (found in
                widget.channel_mapping). When a channel's reference count
                reaches 0, it will be garbage collected itself (see
                @checkForUnusedChannels).
            ###
            for channel in _.values(widget.channel_mapping)
                unless @reference_data[channel]?
                    logger.warn("Couldn't decrease count of #{channel} " +
                                "because it was already removed")
                    continue
                @reference_data[channel]['reference_count'] -= 1
                # Remove this widget's reference from the channel reference
                # data because they will no longer be tied together
                delete @reference_data[channel].widgets[widget.params.widget_id]
                if @reference_data[channel]['reference_count'] == 0
                    @reference_data[channel]['time_of_reference_expiry'] = (new Date).getTime()

        unbindWidgetFromBackboneEvents: (widget) ->
            ###
                Unbinds a widget from all of its related backbone events
                (be it collection-level events or model-level events),
                for classical Backbone collections or for our own RawData.

                The datasource is responsible for this because it's also
                responsible for binding the widget to channel events.
            ###
            for fake_channel, channel of widget.channel_mapping
                if not (channel of @meta_data)
                    logger.warn('Could not unbind widget from collection ' +
                                 channel + ' because it was already gone')
                    continue

                # Start unbinding the widget to the existing channel.
                widget_method = @_getWidgetMethod(fake_channel, widget)
                [collection, item, events] = channels_utils.splitChannel(fake_channel)

                # For relational channel, we have item-level unbinding and
                # collection-level unbinding, depending on the type of widget
                # subscription.
                if @_getType(channel) == 'relational'
                    if item == "all"
                        @data[channel].off(events, widget_method, widget)
                    else
                        individual_item = @data[channel].get(item)
                        # Here we might have a problem: when resetting a
                        # collection, there is no way to keep references to the
                        # old widgets so that we unbind events from them.
                        # TODO(andrei): investigate if we can do something in
                        # the BaseModel class.
                        if individual_item
                            individual_item.off(events, widget_method, widget)
                else if @_getType(channel) == 'api'
                    @data[channel].off(events, widget_method, widget)

        destroyWidget: (widget_data) ->
            ###
                Handler for the /destroy_widget event published by
                widgets when their destroy() method gets called. Their destroy()
                method is called by the widget_starter, when it has detected
                that the widget has been removed from the DOM and the time
                for the widget to be GC'ed has come (GC is done in batches).
            ###
            logger.info("Destroy #{widget_data.name} widget in DataSource")
            @unbindWidgetFromBackboneEvents(widget_data.widget)
            @decreaseReferenceCountsForChannelsOfDestroyedWidget(widget_data.widget)
