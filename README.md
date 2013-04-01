uberVU, the leader of online social media monitoring, makes its own Coffee :)

This is our very own, home-brewed SPA framework. More details:
https://github.com/uberVU/mozaic/raw/master/mozaic.pdf

## Release notes for v0.3:
* released our latest Mozaic core internal version. Starting with this version, we will be eating our own dogfood and using Mozaic core from this repo. More details to follow.

## Release notes for v0.2:
* improved widget starter which now uses DOM Mutation events in order to detect when new widgets are added / removed
* forms support (read the comments!)
* datasource now supports "streampoll", a type of smart poll for a data channel which represents a stream; use-cases are twitter-like feeds where new items appear all the time
* support for automatic inclusion of files in index.html (actually this is a precursor to bundling, but our script just didn't make it in this release)
* loading animation by default
* support for adding new items to collections and deleting items from collections in Datasource
* almost complete isolation of widget crashes (automatic wrapping of all instance methods and new Module() calls)
* garbage collection! Widgets which disappear from the DOM will be killed and the data channels referenced by them also

In this repo you have a TODO list app called TodoVU following the model from [1].

[1]: http://addyosmani.github.com/todomvc/

# How to use Mozaic
This section is still under development...

## Creating a data channel

In `conf/datasource.js`
```js
App.DataSourceConfig = {
  channel_types: {
    '/users': {
      type: 'relational',
      collection: 'users',
      url: '/api/users?format=json'
    }
  }
};
```
* The channel key should always start with a slash `/`
* __type__ _required_
 * `relational` - Uses a collection of models to collect received data, used for list of items of the same type (most cases)
 * `api` - Uses a `RawData` object to collect received data, used for endpoints with fixed fields on a single object
* __collection__ _required_ - The alias name of the collection to be used, as defined in `conf/modules.js`, be it either a `BaseCollection` or a `RawData` subclass
* __url__ - The URL from which data is pulled and pushed upon (`GET`, `POST`, `PUT` and `DELETE`); it can be omitted if the channel data is meant to be both created and consumed on the client only
