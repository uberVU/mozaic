###
    Text translation widget.

    How to use it: inject the widget into the page, tell it the data channel
    to listen to for data and the path within the data channel (for example
    channel is mention/123 and path is 'content'), and it will auto-magically
    translate the given text.
###
define ['cs!widget'], (Widget) ->

    class TranslateTextWidget extends Widget
        template_name: 'templates/translate_text.hjs'

        params_defaults:
            'language': 'data-params'
            'text_path': 'data-params'
            'entity_id': 'data-params'

        initialize: =>
            # We create the translate channel with empy params, and
            # because in datasource.js we have configured it to have
            # 'populate_on_init' set to true, this will skip the initial fetch.
            #
            # We will wait for the data to be translated to arrive,
            # and afterwards refresh the translate channel with the correct params.
            [translate] = Utils.newDataChannels('/translate': {})
            @channel_mapping['/translate'] = translate
            @subscribed_channels.push('/translate')

            # We support listening to an entity which optionally has an ID
            # Typically, an entity without and ID will be an API channel,
            # while an entity with an ID will be an item in a relational channel.
            entity_channel = '/entity_to_translate'
            entity_channel = entity_channel + '/{{entity_id}}' if @entity_id
            @subscribed_channels.push(entity_channel)

        get_entity_to_translate: (params) =>
            ###
                Whenever the data to translate is ready, retrieve it
                and send it to the translation service via HTTP POST.

                Note: even though from a semantic POV, a HTTP GET would
                make more sense, GETs are limited in size while POSTs
                are not (or, to be frank, much less :D).
            ###
            text = params.model.get(@text_path)
            translate_params =
                text: text
                language: @language
            @refreshChannel('/translate', translate_params)

        get_translate: (params) =>
            ###
                Whenever the translated text arrives back from the server,
                display it.
            ###
            @renderLayout({text: params.model.get('responseData/translatedText')})

    return TranslateTextWidget