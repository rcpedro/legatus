# Legatus
Build business directives in Rails. A `Legatus::Directive` has the following properties:

1. `params` - The raw parameters from a controller.
2. `props` - The filtered out from params. In traditional Rails apps, these are usually declared in the controller (e.g. for a scaffolded `BookController`, there will be a `book_params` method which filters the raw parameters).
2. `errors` - Errors encountered during the directive's execution.

A `Legatus::Directive` also has the following default lifecycles called in sequence in the directive's `execute` (apart from initialize which is called on creation of the directive) method:

1. `initialize` - Accepts raw parameters and prepares `props`.
2. `clean` - Validate the extracted `props` for any missing or wrongly formatted input.
3. `load` - Load models from the cleaned `props`.
4. `validate` - Validate the loaded models (e.g. by default, done by calling `valid?` on them)
5. `persist` - Persist the changes onto the database.

When calling `execute`, each of the lifecyle methods is expected to return a value that is truthy or falsy. If the return value is falsy, the execution stops (e.g., if `clean` returns false, `load`, `validate`, and `persist` will no longer be called). A directive can also have before and after callbacks for each of the lifecycle methods.

A directive can be defined in two ways:
1. Overriding the lifecycle methods.
2. Specifying meta information which will be used by the superclass' default methods.

## Usage

TODO

### Initialize
### Clean
### Load
### Validate
### Initialize


## Installation
Add this line to your application's Gemfile:

```ruby
gem 'legatus'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install legatus
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
