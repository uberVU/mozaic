define ['cs!widget'], (Widget) ->
    class SyncUrlWidget extends Widget
        # Aggregated channels call the designated method without waiting
        # to have at least one event from each data channel first.
        aggregate_without_join: true

        # Don't receive fake events from the datasource
        # when subscribing to a data channel with existing data in it.
        skip_fake_events: true

        initialize: =>
            ###
                Initializes the SyncUrlWidget.

                Dynamically sets subscribed_channels and aggregated_channels
                according to the parameters passed to the widget through data-params.
                Params that should be passed to the widget:
                - url_changing_channels: the channels to which this 
                    widget will react by modifying the URL
                - controller: the name of the controller so that the widget
                    can execute its build_url() method

                Returns: nothing.
            ###
            if not ('controller_config' of @params)
                logger.error('SyncUrlWidget is missing controller_config')
                return

            if not ('url_changing_channels' of @params.controller_config)
                logger.error('SyncUrlWidget is missing url_changing_channels')
                return

            # This widget is subscribed to all the channels
            # that might trigger the URL change.
            @subscribed_channels = @params.controller_config.url_changing_channels

            # We receive notifications from the channels we're subscribed to
            # on the same function: rebuild_url
            @aggregated_channels = {rebuild_url: @subscribed_channels}

        rebuild_url: (event_params...) =>
            ###
                Event handler for each of the data channels that might trigger
                and URL rebuild.

                event_params...: a vector of parameters, one from each data channel

                Returns: nothing.
            ###

            # Try to get an instance of the controller
            name = @params.controller_config.controller
            controller = loader.get_module('cs!controller/' + name)
            if not controller
                logger.error('Could not find instance of controller ' + name)
                return

            # Run the build_url method of the controller using the parameters
            # received from the datasource. This will give us the new URL.
            new_url = controller.build_url(event_params...)

            # Run the navigate() method of backbone router to navigate to the new URL.
            # Make sure we don't trigger a new router match.
            router = loader.get_module('cs!router')
            router.navigate(new_url, {trigger: false})

    return SyncUrlWidget