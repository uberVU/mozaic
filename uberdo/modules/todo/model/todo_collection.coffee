define ['cs!base_collection', 'cs!model/todo'], (BaseCollection, TodoModel) ->

    class TodoCollection extends BaseCollection
        model: TodoModel
