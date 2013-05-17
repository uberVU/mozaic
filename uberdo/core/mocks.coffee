define ['cs!api_mock'], (ApiMock) ->
    ###
        This module is intended to mock/alter ajax requests.
        It does this by using test factories to generate data (@see `master_factory.coffee`)
        and hooking it into datasource using mockjax (@see api_mock.coffee)
        This module is included only in testing/development environments,
        depending on the App.general.USE_MOCKS flag, and is executed before any other
        componenet of the app.
    ###
    ApiMock.apiMock(
        report_widgets: [
                type: 'line_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['gender', 'sentiment']
            ,
                type: 'pie_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['gender', 'sentiment']
            ,
                type: 'donut_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['gender', 'sentiment']
            ,
                type: 'bar_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['gender', 'sentiment']
            ,
                type: 'stacked_area_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['gender', 'sentiment']
            ,
                type: 'spline_chart'
                metric: 'count'
                breakdown: 'generator'
                filters: ['generator']
        ]
        # This hack is needed to make the CurrentFactory usable to mock the
        # /current api endpoint. This needs to return and array with an `is_api`
        # flag setup.
        # @see api_mocks.coffee#getMockedApiResponse
        'current': [{
            is_api: true
        }]
    )
    # Mock stream refresh w/out any factory around it
    ApiMock.mockResource('keywords/[0-9]+/refresh', {})
