define ['cs!tests/factories/master_factory'], (MasterFactory) ->
    ###
        TODO: Document mocking params
    ###
    master_factory = new MasterFactory()

    ApiMock =

        # Property exposes MasterFactory's mapping between channels
        # and factories.
        channelsToFactoriesMapping: \
            master_factory.getChannelsToFactoriesMapping()

        apiMock: (resources) ->
            ###
                Mock some api calls.
            ###
            result = {}
            if not @mocks
                @mocks = {}
            for resource, params of resources
                if params.response
                    response = params.response
                else
                    response = @getMockedApiResponse(resource, params)
                id = @mockResource(resource, response, params)
                # Save the id to be able to clear it later and rebind it.
                @mocks[resource] = id

                # Depending on the channel type (relational or api), populate
                # the response object the same way as the objects would be
                # received inside the channel callback
                if response.objects
                    result[resource] = response.objects
                else
                    result[resource] = response
            return result

        mockResource: (resource, response, params = {}) ->
            # The mockjax_options allow you to pass extra params
            # to the mockjax configuration.
            # Example of use case:
            # you want the status to be 403, not 200 which is by
            # default.
            $.mockjax(
                _.extend({}, params.mockjax_options,
                    url: @getResourceRegExp(resource)
                    response: ->
                        @responseText = response
                )
            )

        getResourceRegExp: (resource) ->
            endpoint = "#{App.general.FRONTAPI_URL}/.*/#{resource}/([^a-z]|$)"
            return new RegExp(endpoint)

        getMockedApiResponse: (resource, params) ->
            ###
                Mock some API response
            ###
            response = master_factory.get(resource, params)
            # If is_api channel do not wrap the response under 'objects' key
            # Useful for calls to analytics
            # Api responses should be returned directly, w/out being wrapped
            # inside any array (this should be the default actually)
            if response?.is_api
                return response
            else if response[0]?.is_api
                return response[0]
            else
                if not _.isArray(response)
                    response = [response]
                return {'objects': response}

        clearResource: (resource) ->
            $.mockjaxClear(@mocks[resource])

        mockChannel: (args) ->
            ###
                This method mocks channels. It create It uses @apiMock internally,
                however it mocks and creates __one__ channel instead of
                mocking multiple urls.

                @see tests/modules/reports/widget/report_widget_sentiment_meter_form.coffee#injectSentimentMeterForm()
                @param {Object} args
                @param {String} args.type - the channel type to mock
                                  @see conf/datasource.js for channel types.
                @param {Object} args.params - params to pass on to ApiMock.
                            Defaults to {}. @see BaseTest#_apiMock for params.
                @param {Object} args.channel_params - optional params for
                                channel creation - used for the cases when
                                creating a channel needs mandatory params
                                for building the channel URL.

                @return {Object} output - an object with the following props:
                @return {String} output.id - id of newly created channel
                @return {Object|Array} output.data - data that will be served
                            to the channel when a request to it will be made.

            ###
            factoryType = ApiMock.channelsToFactoriesMapping[args.type]
            unless factoryType?
                throw new Error "No factory for channel `#{args.type}`"

            new_data_channels_params = {}
            new_data_channels_params[args.type] = args.channel_creation_params or {}
            [channelInstanceId] = Utils.newDataChannels(new_data_channels_params)

            mockParams = {}
            mockParams[factoryType] = args.params or {}
            channelMocks = @apiMock(mockParams)[factoryType]

            # Always return an array for consistency
            if not _.isArray(channelMocks)
                channelMocks = [channelMocks]

            output =
                id: channelInstanceId
                data: channelMocks

