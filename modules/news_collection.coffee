define ['cs!model/news'], (News) ->
    class NewsCollection extends Backbone.Collection
        model: News
    return NewsCollection

