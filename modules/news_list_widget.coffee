define ['cs!widget'], (Widget) ->
    class NewsListWidget extends Widget
        subscribed_channels: ['/news']
        template_name: 'templates/news_list_widget.hjs'

        get_news: (params) =>
            ###
                This method will be called whenever there are changes
                to the /news channel. Changes can be of multiple types,
                as this data channel is actually a Backbone Collection.
                (There is another type of channel as well, which can store raw
                JSON data).
            ###
            @renderLayout({"news" : params.collection.models})

    return NewsListWidget

