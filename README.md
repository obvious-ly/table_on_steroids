# TableOnSteroids

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/table_on_steroids`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'table_on_steroids'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install table_on_steroids

## Usage

### Add assets

application.js

```
//= require table_on_steroids
```

application.scss
```
    @import "table_on_steroids";
```

### In the controller
#### Add the concern 

```
  require 'table_on_steroids'
  include TableOnSteroids::TableConcern
```

#### Define a global search (optional)*
```
  def global_search
    @global_search_lambda ||= nil #put whatever lambda you want here -> (objects, query) { objects.deep_search(query) }
  end
```

#### Define your columns

The columns are defined by a hash: 
Key: a key defining the column

options:
 - *label*: column title
 - *type*:
 - *value_lambda*: how to get the value of this object. "context" is the view context. You can use it to call view methods (eg: `context.link_to` ... ; `context.render` ...)
 - array : array lambdas for search and order
        - filter_lambda
        - order_lambda
        - search_lambda
        - default_order (true|false)
 - activerecord : activerecord lambdas for search and order
        - filter_lambda
        - order_lambda
        - search_lambda
        - default_order (true|false)


```
def columns_on_steroid
    @columns_on_steroid ||= {
      'email' => {
        label: "email",
        type: 'order',
        array: {
          order_lambda: -> (objects) { objects.sort_by{ |o| o.user.email.downcase } }
        },
        activerecord: {
          search_lambda: -> (objects, v) { objects.joins(:user).where('users.email ilike ?', ("%" + v + "%")) }
        },
        value_lambda: -> (object, context) { object.user.email } 
      }, ..
```
#### Use the columns to search and order
```
    @objects = filter_and_order(@objects, columns_on_steroid, global_search)
```
#### Use the columns to create a csv
add *download_value_lambda* to your table columns
```
    table_csv(@objects , columns_on_steroid_fulfillment)
```

### In the view

Render the table

```
    = render partial: 'table_on_steroids/table_on_steroids', locals: { objects: @objects, columns: @columns_on_steroid}

```

_locals extra options:_
- title
- download_csv: the link of the download csv 
- table_on_steroid_id
- omit_columns



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/table_on_steroids. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Build and deploy a new version

1. Upgrade the version number
2. `gem build table_on_steroids` it will create a .gem file
3. `gem push table_on_steroids-[newversion].gem`

Adding an owner `gem owner --add {{email}} {{gem}}` (the person must have a https://rubygems.org/ account)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TableOnSteroids project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/table_on_steroids/blob/master/CODE_OF_CONDUCT.md).
