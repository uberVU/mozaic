###
    Loader component which is concerned with modules / widgets updating.
###
define [], () ->
    loader =
        modules: {}
        widgets: {}

        normalize_path: (path) ->
            if path?
                return "#{path.replace(/cs!/, '')}"

        load_module: (original_path, callback=null, instantiate=true, params...) ->
            ###
                Load a module at a given path
            ###
            path = loader.normalize_path(original_path)

            logger.info "Loading module #{path}"

            require [original_path], (Module) ->
                loader.modules[path] = {module: Module}
                if instantiate
                    if not (loader.modules[path]['instance'])
                        instance = new Module(params...)
                        instance.initialize()
                        loader.modules[path]['instance'] = instance
                    else
                        instance = loader.modules[path]['instance']
                loader.modules[path]['running'] = true

                # Execute the callback with instance if instantiate was enabled
                # or without any params if we only wished to load the module code.
                if instantiate
                    callback(instance) if callback
                else
                    callback() if callback

        load_modules: (paths, callback=null, instantiate=true) ->
            ###
                Load multiple modules given their paths.

                The callback is called once __all__ modules are loaded.
            ###

            # Make a request to require.js to load the modules with all their dependencies
            require paths, (modules...) =>
                for i in [0..paths.length-1]
                    path = loader.normalize_path(paths[i])
                    Module = modules[i]

                    # Initialize the registry of modules for the current module
                    if not (path of loader.modules)
                        loader.modules[path] = {}

                    loader.modules[path].module = Module
                    # If we should instantiate this module and there isn't
                    # already an instance, create it
                    if instantiate and not (loader.modules[path]['instance'])
                        instance = new Module()
                        instance.initialize()
                        loader.modules[path]['instance'] = instance
                    loader.modules[path]['running'] = true

                # Run the callback if there is one, when all the modules have been loaded.
                if instantiate
                    # If instantiate was enabled, we will build a list of all instances
                    # of the modules (not just the ones that have been loaded this time,
                    # but also the ones that were already loaded).
                    instances = [loader.modules[loader.normalize_path(path)]['instance'] for path in paths]
                    callback(instances...) if callback
                else
                    callback() if callback

        unload_module: (original_path, callback = null) ->
            ###
                Unload a module at a given path
            ###
            path = loader.normalize_path(original_path)

            logger.info "Unloading module #{path}"
            if not path of loader.modules
                return
            # Destroy the instance if there is one
            if loader.modules[path]['instance']
                instance = loader.modules[path]['instance']
                instance.destroy()
            delete loader.modules[path]
            callback(path) if callback

        get_module: (original_path) ->
            ###
                Getting an instatiated module
            ###
            path = loader.normalize_path(original_path)

            if path of loader.modules and loader.modules[path].running
                return loader.modules[path].instance
            else
                logger.warn "Trying to get unavailable module #{path}"

        instantiate_widget: (name, id, params) ->
            ###
                Instantiates a given widget, when we know for a fact that its
                code has been loaded client-side.
            ###
            path = "cs!widget/" + name
            path = loader.normalize_path(path)

            if not path of loader.modules
                logger.error "Trying to instantiate a widget that hasn't been loaded: #{name}"
                return

            Module = loader.modules[path]['module']

            # Check if widget has also template_name declaration.
            # If it does, also load the template.
            # TODO: refactor load_modules so that it supports params as well,
            #       so we can take advantage of parallel loading for the
            #       widget code and its template.
            template_name = params.template_name or Module.prototype.template_name
            if template_name
                template_path = 'text!' + template_name
                require([template_path], (tpl) ->
                    loader.widgets[id] = new Module(params, tpl)
                )
            else
                # We don't need to fire initialize() here because the
                # base method Widget.constructor() does.
                loader.widgets[id] = new Module(params)

        load_widget: (name, id, params) ->
            ###
                Load a given widget given its name and a unique ID to identify
                it system-wide. This ID will usually be a combination between
                the name of the template and the name of the widget.

                The path will always be "widget/<name>", which should be configured
                in the require.js configuration to point to the correct file.
            ###
            logger.info "Loading widget #{id} (name = #{name })"
            path = "cs!widget/" + name

            callback = => loader.instantiate_widget(name, id, params)
            loader.load_module(path, callback, false)

        unload_widget: (id) ->
            ###
                Unload a widget given its id
            ###
            logger.info "Unloading widget #{id}"

    window.loader = loader
    return loader