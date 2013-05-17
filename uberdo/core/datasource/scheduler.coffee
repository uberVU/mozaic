define [], () ->

    class DataSourceScheduler
        ###
            Includes methods to ...
        ###

        pushDataAfterScroll: (channels) ->
            ###
                This gets called every time a widget publishes to "/scroll"

                Data sources receives the scrollable_channels, sets the new collection
                page based on the channels, which will trigger the widget to update
            ###

            # For each of the scrollable channels the widget is subscribed to
            for channel in channels
                do (channel) =>
                    logger.info "Scrolling #{channel} in DataSource"
                    @_fetchChannelDataFromServer(channel, 'scroll')

        pushDataAfterRefresh: (channels, options = {}) ->
            ###
                This gets called every time a widget publishes to "/refresh"

                Data sources will update the data channel according to its
                configured policy.

                Here it can happen a flush channel buffer or a channel refresh
                To skip the buffer flush pass skipStreampollBuffer = true in options param
            ###

            # If channels is an array, it means that we're not receiving any
            # parameters to the channels refresh.
            if $.isArray(channels)
                dict = {}
                for channel in channels
                    # Use existing params if no params were specified
                    dict[channel] = @meta_data[channel].params
            # Otherwise, we're getting channel-specific params for refresh
            else if $.isPlainObject(channels)
                dict = channels
            else
                logger.warn("Unknown parameter type for pushDataAfterRefresh: #{channels}")
                return

            for channel, params of dict
                do (channel, params) =>
                    logger.info "Sends data to #{channel} in DataSource"

                    params_modified = not _.isEqual(@meta_data[channel].params, params)
                    @meta_data[channel].params = params if params_modified

                    # Allow to skip a streampoll buffer flush
                    # By default skip_streampoll_buffer = false
                    skip_streampoll_buffer = if options.skipStreampollBuffer? then options.skipStreampollBuffer else false

                    config_buffer_size = @_getBufferSize(channel)
                    channel_has_buffer = config_buffer_size > 0

                    # Current buffer length is 0 if channel is not configured with a buffer
                    current_buffer_size = if channel_has_buffer then @data[channel].buffer.length else 0

                    # If channel has no buffer that buffer_is_full = true
                    buffer_is_full = current_buffer_size >= config_buffer_size

                    # Refresh channel if these conditions are met:
                    #  - skip_streampoll_buffer = true, or
                    #  - The channel buffer is full, or
                    #  - The channel params were modified
                    if skip_streampoll_buffer or buffer_is_full or params_modified
                        # If we have to do a fresh fetch from the server,
                        # empty the existing buffer first
                        @data[channel].buffer.reset([]) if channel_has_buffer
                        @_fetchChannelDataFromServer(channel)
                        @_restartRefreshing(channel)
                    else
                        @_flushChannelBuffer(channel)

        _scheduleNextRefresh: (channel_key, success) ->
            ###
                Schedule the next refresh for a given channel and a reason.
                The next refresh will call this function again via callback,
                to schedule the next refresh after that, and so on.
            ###
            # Are we still refreshing this channel?
            if not @meta_data[channel_key].refreshing
                return

            # Basic refresh_after.
            refresh_after = @_getRefreshInterval(channel_key)

            # Do not apply the backoff algorithm to fetching failures.
            if @_getConfig(channel_key).refresh == 'backoff' and success
                # Current item count = data + buffer
                current_item_count = @data[channel_key].length
                if 'buffer' of @data[channel_key]
                    current_item_count += @data[channel_key].buffer.length

                # If there are no new items, increment backoff, otherwise reset it.
                if current_item_count == @meta_data[channel_key].last_item_count
                    # Initialize the exponential backoff to 1, then double it.
                    if not @meta_data[channel_key].backoff
                        @meta_data[channel_key].backoff = 1
                    @meta_data[channel_key].backoff *= 2
                    refresh_after *= @meta_data[channel_key].backoff
                    # Ensure refresh_after < max_refresh_interval.
                    refresh_after = Math.min(refresh_after, @_getMaxRefreshInterval(channel_key))
                    logger.info "Refreshing #{channel_key} after #{refresh_after}ms"
                else
                    # Some new items, reset backoff.
                    @meta_data[channel_key].backoff = 1
                    logger.info "Reset backoff for #{channel_key}"

                # TODO(mihnea): if a scroll down event is triggered, the number
                # of items in the channel will increase, regardless of the
                # refreshing logic. This will be perceived as "new data" and
                # we might refresh sooner than needed because of it.
                # Possible fix: recompute last_item_count after each
                # reason='scroll' refresh.
                # Update last_item_count.
                @meta_data[channel_key].last_item_count = current_item_count

            # Configure periodic refresh with reason="refresh" or "streampoll"
            # (or "scroll", but that makes very little sense).
            refresh_type = @_getRefreshType(channel_key)
            handle = setTimeout((=> @_fetchChannelDataFromServer(channel_key, refresh_type, @_scheduleNextRefresh)),
                                refresh_after)
            @meta_data[channel_key].timeout_variable = handle
