define ['cs!model/todo'], (Todo) ->
    class TodoCollection extends Backbone.Collection
        model: Todo
    return TodoCollection