###
    Loader component which is concerned with modules / widgets updating.
###
define [], () ->

    if not Handlebars.templates
        Handlebars.templates = {}

    loader =
        modules: {}
        widgets: {}
        born_dead: {}

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
                if not (path of loader.modules)
                    loader.modules[path] = {module: Module}
                if instantiate
                    if not (loader.modules[path]['instance'])
                        instance = Utils.createModuleInstance(Module, params...)
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
                        instance = Utils.createModuleInstance(Module)
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

            if not (path of loader.modules)
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
                loader.load_template(template_name, (tpl) ->
                    # Don't instantiate widgets which should have already been
                    # garbage collected.
                    if loader.born_dead[id]
                        cloned_params = _.clone(params)
                        delete cloned_params['el']
                        logger.warn("Widget with id #{id} was born dead (params = #{JSON.stringify(cloned_params)}). You're doing something wrong.")
                        delete loader.born_dead[id]
                        return
                    loader.widgets[id] = Utils.createModuleInstance(Module, params, tpl)
                )
            else
                # Don't instantiate widgets which should have already been
                # garbage collected.
                if loader.born_dead[id]
                    cloned_params = _.clone(params)
                    delete cloned_params['el']
                    logger.warn("Widget with id #{id} was born dead (params = #{JSON.stringify(cloned_params)}). You're doing something wrong.")
                    delete loader.born_dead[id]
                    return
                # We don't need to fire initialize() here because the
                # base method Widget.constructor() does.
                loader.widgets[id] = Utils.createModuleInstance(Module, params)

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

        mark_as_detached: (widget_id) ->
            ###
                Marks a widget as being detached from the DOM. This is an
                intermediary state while the widget is waiting to be garbage
                collected and it should not receive any data events while
                in this state.
            ###
            if loader.widgets[widget_id]
                loader.widgets[widget_id].startBeingDetached()
            else
                loader.born_dead[widget_id] = true

        destroy_widget: (widget_id) ->
            if loader.widgets[widget_id]
                loader.widgets[widget_id].destroy()
                delete loader.widgets[widget_id]
            else
                loader.born_dead[widget_id] = true

        get_widgets: ->
            loader.widgets

        load_template: (template_name, callback) ->
            if template_name?
                template_path = 'text!' + template_name
            else
                # No need to return the callback if the temple_name is invalid
                return

            if App.general.USE_PRECOMPILED_TEMPLATES
                tpl_suffix = template_name.slice(-3)
                if tpl_suffix == 'hjs'
                    template_path = template_name.slice(0, -3) + 'js'
                else
                    logger.error("Trying to load an invalid template with name #{template_name}")
                    return

            require [template_path], (tpl) ->
                # If the template is served in production and is precompiled,
                # send the precompiled version
                if App.general.USE_PRECOMPILED_TEMPLATES
                    callback(Handlebars.templates[template_name])
                else
                # Cache the compiled version and send it to the callback
                    if not Handlebars.templates[template_name]
                        Handlebars.templates[template_name] = Handlebars.compile(tpl)

                    callback(Handlebars.templates[template_name])

    window.loader = loader
    return loader
