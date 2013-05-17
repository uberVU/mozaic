define ['cs!base_collection', 'cs!model/news'], (BaseCollection, NewsModel) ->
    class NewsCollection extends BaseCollection
        model: NewsModel
