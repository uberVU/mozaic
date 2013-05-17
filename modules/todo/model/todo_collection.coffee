define ['cs!base_collection', 'cs!model/todo'], (BaseCollection, TodoModel) ->

    class TodoCollection extends BaseCollection
        model: TodoModel

        comparator: (a, b) ->
            # Sort by checked
            if a.get('checked') is b.get('checked')
                # Sort by starred
                if a.get('starred') is b.get('starred')
                    # Sory by timestamp
                    return 0
                else return if a.get('starred') then -1 else 1
            else return if a.get('checked') then 1 else -1
