define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceRefresher
        ###
            Includes methods to refresh data on channels
        ###

        _startRefreshing: (channel) ->
            ###
                Start the refreshing policy for the given channel:
                periodic or backoff.
            ###
            channel_key = channels_utils.getChannelKey(channel)

            # Make sure this channel needs to be refreshed.
            refresh_interval = @_getRefreshInterval(channel_key)
            if not refresh_interval
                return

            # Make sure we don't do setTimeout() more than once per channel.
            if @meta_data[channel_key].refreshing
                return

            # Mark the fact that we're refreshing.
            @meta_data[channel_key].refreshing = true

            # Initialize backoff.
            if @_getConfig(channel_key).refresh == 'backoff'
                @meta_data[channel_key].backoff = 1

            @_scheduleNextRefresh(channel_key, true)

        _stopRefreshing: (channel_key) ->
            ###
                Cancel the current refresh request, and stop future ones
                for the given channel.
            ###
            # Stop future refresh requests.
            @meta_data[channel_key].refreshing = false
            # Stop the current refresh request (if any).
            if @meta_data[channel_key].timeout_variable
                clearTimeout(@meta_data[channel_key].timeout_variable)

        _restartRefreshing: (channel_guid) ->
            # Restart the refreshing cycle. When refresh = 'backoff' and the
            # buffer is full, the backoff will be maxed out. Restarting will
            # also reset the buffer to its minimum value, and renew
            # the refreshing cycle.
            @_stopRefreshing(channel_guid)
            @_startRefreshing(channel_guid)

        _getRefreshInterval: (channel) ->
            ###
                Returns the periodic refresh interval for a given channel.

                channel: the channel to check
                Returns: the interval ifthe channel has periodic refresh
                         configured, 0 otherwise
            ###
            conf = @_getConfig(channel)
            if conf.refresh and 'refresh_interval' of conf
                return conf.refresh_interval
            else
                return 0

        _getMaxRefreshInterval: (channel) ->
            ###
                Returns the maximum refresh interval for a given channel -
                defaults to default_max_refresh_factor x refresh intreval.
            ###
            conf = @_getConfig(channel)
            if conf.max_refresh_interval
                return conf.max_refresh_interval
            else
                return @default_max_refresh_factor * @_getRefreshInterval(channel)

        _getRefreshType: (channel) ->
            ###
                Returns the refesh type for a given channel:
                'refresh' (default), 'streampoll', or 'scroll'.
            ###
            return @_getConfig(channel).refresh_type or "refresh"
