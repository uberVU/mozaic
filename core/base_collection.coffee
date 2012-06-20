define [], () ->
    class BaseCollection extends Backbone.Collection

        parse: (response) ->
            return response.objects if response.objects
            return {}

    return BaseCollection