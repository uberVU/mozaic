define ['cs!widget'], (Widget) ->

    class UrlWidget extends Widget
        # Don't wait for events from all types of params to appear before
        # triggering get_new_params
        aggregate_without_join: true

        template_name: 'templates/url.hjs'
        params_defaults:
            'ignored_params': 'data-params'

        events:
            "click a.url-widget-link": "navigateToDestination"

        params_defaults: {
            base_url: 'data-params',
            subscribed_channels: -> _.keys(@channel_mapping)
            aggregated_channels: -> {get_new_params: @subscribed_channels},
            text: 'data-params',
        }

        navigateToDestination: (event) =>
            router = loader.get_module('cs!router')
            hash = event.currentTarget.hash[1..]
            router.navigate(hash, {trigger: true})
            return false

        get_new_params: (params...) =>
            ###
                Whenever new parameters arrive build a new URL and render it.
                The URL rendering algorithm is the same as in datasource.
            ###
            all_params = {}
            for param_set in params
                _.extend(all_params, param_set.model.toJSON())

            # Make sure to ignore some parameters when rendering URLs.
            # Use-case: ignore heterogeneous sort-by for twitter stream
            # main sections.
            if @ignored_params
                final_params = {}
                for k, v of all_params
                    if not (k in @ignored_params)
                        final_params[k] = v
                all_params = final_params

            url = Utils.render_url(@base_url, all_params)
            url = Utils.current_url() + '#' + url
            x = {url: url, text: @text}
            @renderLayout(x)

    return UrlWidget