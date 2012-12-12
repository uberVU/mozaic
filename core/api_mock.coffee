define ['cs!tests/factories/master_factory'], (MasterFactory) ->
    ###
        TODO: Document mocking params
    ###
    master_factory = new MasterFactory()

    Methods =
        apiMock: (params) ->
            ###
                Mock some api calls.
            ###
            result = {}
            for resource, param of params
                endpoint = "#{App.general.FRONTAPI_PREFIX}/#{resource}"
                r = '.*' + endpoint.replace(/\//g, '\\/') + '.*'
                regexp = new RegExp('.*' + endpoint.replace(/\//g, '\\/') + '.*')
                mocked_response = @getMockedApiResponse(resource, param)
                $.mockjax(
                    url: regexp
                    responseText: mocked_response
                )
                result[resource] = mocked_response['objects']
            return result

        getMockedApiResponse: (resource, param) ->
            ###
                Mock some API response
            ###
            response = master_factory.get(resource, param)
            # If is_api channel do not wrap the response under 'objects' key
            # Useful for calls to analytics
            if response[0]?.is_api
                return response[0]
            else
                return {'objects': response}

    return Methods
