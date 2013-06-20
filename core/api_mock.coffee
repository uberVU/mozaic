define ['cs!tests/factories/master_factory'], (MasterFactory) ->
    ###
        TODO: Document mocking params
    ###
    master_factory = new MasterFactory()

    Methods =

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
                return {'objects': response}

        clearResource: (resource) ->
            $.mockjaxClear(@mocks[resource])