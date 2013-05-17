define ['cs!controller'], (Controller) ->
    class NewsListController extends Controller
        action: =>
            [news] = Utils.newDataChannels({'/news': {}})

            params =
                news_list_params:
                    'channels':
                        '/news': news

            @renderLayout(params)
