define ['cs!controller'], (Controller) ->
    class TodoListController extends Controller
        action: =>
            [todos] = Utils.newDataChannels({'/todos': {}})

            params =
                todo_list_params:
                    'channels':
                        '/todos': todos
                todo_add_params:
                    'channels':
                        '/todos': todos

            @renderLayout(params)

    return TodoListController