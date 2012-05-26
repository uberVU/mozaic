define ['cs!model/todo'], (Todo) ->
    class TodoCollection extends Backbone.Collection
        model: Todo

        comparator: (a, b) =>
            # Sort by checked
            if a.get('checked') == b.get('checked')
                # Sort by starred
                if a.get('starred') == b.get('starred')
                    # Sory by timestamp
                    return 0

                else return if a.get('starred') then -1 else 1
                
            else return if a.get('checked') then 1 else -1

    return TodoCollection