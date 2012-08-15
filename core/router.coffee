define ['cs!module'], (Module) ->
    class Router extends Backbone.Router
        delegateToController: (controller_config, params...) =>
            ###
                Delegates the action of the controller to a specialized class
                which is configured in App.urls.
            ###
            module = "cs!controller/" + controller_config.controller
            page_layout = App.general.PAGE_LAYOUT

            # Get the last parameter from "params" and filter it according to
            # the allowed_get_params controller configuration.
            get_params = params.pop()
            filtered_params = {}
            # Check if there is a definition of allowed_get_params first.
            # IF THERE IS NONE, ASSUME THAT NO GET PARAMS ARE EXPECTED (!!!)
            if 'allowed_get_params' of controller_config
                for k, v of get_params
                    if k in controller_config.allowed_get_params
                        filtered_params[k] = v
            params.push(filtered_params)

            # Load controller layout
            loader.load_template( page_layout, (page_template) =>
                loader.load_module('cs!application_controller', (app_controller) =>
                    app_controller.new_controller(controller_config, params)
                , true, App.general.PAGE_LAYOUT)
            )

        constructor: (urls) ->
            ###
                Our router constructor receives a copy of App.urls array,
                parses it and creates a routes array that will get passed
                to the Backbone Router constructor.
            ###
            @urls = urls
            @routes = {}
            @regexp_to_route = {}
            for path, data of urls
                controller = @urls[path].controller
                @routes[path] = "delegateToController"
                regexp = @_routeToRegExp(path)
                @regexp_to_route[regexp] = path
                data.url = path
            super({routes: @routes})

        namedParam    = /:\w+/g
        splatParam    = /\*\w+/g
        escapeRegExp  = /[-[\]{}()+?.,\\^$|#\s]/g

        _routeToRegExp : (route) ->
            route = route.replace(escapeRegExp, "\\$&")
                         .replace(namedParam, "([^\/?]*)")
                         .replace(splatParam, "([^\?]*)")
            route += '[/]?([\?]{1}.*)?'
            return new RegExp('^' + route + '$')

        _extractParameters: (route, fragment) ->
            ###
                We override Backbone.Router's parameter extraction method to also
                return the route for which the parameters were extracted to the
                callback function. This allows us to use the same function
                (delegateToController) for multiple urls.
            ###
            result = super(route, fragment)
            path = @regexp_to_route[route]
            result.unshift(@urls[path])
            result
    return Router
