define ['cs!controller'], (Controller) ->

    class TodoController extends Controller
        action: =>
            # Create a new data channel holding the TODO list items.
            #
            # In a real world app, this channel will contain data fetched
            # from a RESTful API. In our toy application, data is taken
            # from fixture.js :) The channel configuration can be found in
            # datasource.js.
            #
            # In the variable "todos", we are storing a unique identifier
            # of the todos channel in the datasource.
            [todos] = Utils.newDataChannels
                '/todos':
                    _initial_data_: Constants.TODO_MOCKS

            # We're using Handlebars.js for templating and in the template
            # associated with this controller (todo_page.hjs, configured in
            # urls.js) there are two widgets injected (with div class="mozaic-widget").
            # One is for the add task widget, and one for the task list widget.
            params =
                # Parameters passed to the TODO list widget.
                # It needs to have access to the todos channel in order to
                # display the items and treat events like new items added.
                todo_list_params:
                    channels:
                        '/items': todos
                    item: 'todo'
                    item_channels:
                        '/todos': todos
                    item_element: 'tr'
                # Parameters passed to the add todo widget. It needs to know
                # the channel in order to add items to it.
                todo_form_params:
                    channels:
                        '/todos': todos

            # Render the layout (templates/todo/controller.hjs)
            @renderLayout(params)
