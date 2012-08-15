define [], () ->

    class Layout
        constructor: (path, params) ->
            @path = path
            @params = params
            @stringified_params = {}
            for k, v of @params
                if $.isPlainObject(v) or $.isArray(v)
                    @stringified_params[k] = JSON.stringify(v)
                else
                    @stringified_params[k] = v

        renderHTML: (el = null, stringify = true) ->
            ###
                Load the widgets for the given template
            ###

            logger.info('Loading layout ' + @path)

            # Load the template via require.js text plugin
            loader.load_template @path, (compiled_template) =>
                if stringify
                    template = compiled_template(@stringified_params)
                else
                    template = compiled_template(@params)
                template = "<!--Template: #{@path} -->" + template
                if not el
                    el = $('#page-content')
                el.html(template)

    return Layout