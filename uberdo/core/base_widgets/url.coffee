define ['cs!widget'], (Widget) ->

    class UrlWidget extends Widget
        # Don't wait for events from all types of params to appear before
        # triggering get_new_params
        aggregate_without_join: true

        template_name: 'templates/url.hjs'
        params_defaults:
            base_url: 'data-params',
            subscribed_channels: -> _.keys(@channel_mapping)
            aggregated_channels: -> {get_new_params: @subscribed_channels}
            text: 'data-params',
            ignored_params: 'data-params'
            extra_params: 'data-params'
            extra_classes: 'data-params'

        events:
            "click a.url-widget-link": "navigateToDestination"

        navigateToDestination: (event) =>
            hash = event.currentTarget.hash[1..]
            Utils.goto(hash, true)
            return false

        get_new_params: (params...) =>
            ###
                Whenever new parameters arrive build a new URL and render it.
                The URL rendering algorithm is the same as in datasource.
            ###
            final_params = {}
            original_params = {}
            for param_set in params
                _.extend(original_params, param_set.model.toJSON())

            # Make sure to ignore some parameters when rendering URLs.
            # Use-case: ignore heterogeneous sort-by for twitter stream
            # main sections.
            if @ignored_params
                for k, v of original_params
                    if not (k in @ignored_params)
                        final_params[k] = v
            else
                final_params = original_params

            # You can give additional params that might not fit in the base_url
            # Use-case: moving between the my_tasks all_tasks sections on tasks
            if @extra_params
                for k, v of @extra_params
                    final_params[k] = v

            url = Utils.render_url(@base_url, final_params)
            url = Utils.current_url() + '#' + url
            x = {url: url, text: @text, extra_classes: @extra_classes}

            @renderLayout(x)

    return UrlWidget