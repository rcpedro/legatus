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

To create a directive, the class `Legatus::Directive` should be extended and the models handled by the directive should be declared using `attr_accessor`:
```ruby
class Product::Item::Save < Legatus::Directive
  attr_accessor :item
end
```

For this example, we will be creating a directive for saving a Product which is an ActiveRecord object, wherein a Product can have many UnitPrices. 

### Initialize

The first step when dealing with directives is converting params from controllers into properties. In traditional Rails controllers, we would usually find:

```ruby
protected
  def order_params
    params[:item].permit(:id, :name, :description, :merchant_id, :status)
  end

  def line_item_params
    params[:item].permit(unit_prices: [:price, :effective_date, :_destroy])
  end
```

In our directive, the above would look like:

```ruby
class Product::Item::Save < Legatus::Directive
  attr_accessor :item

  def initialize(params)
    @props = {
      order:       params[:item].permit(:id, :name, :description, :merchant_id, :status),
      unit_prices: params[:item].permit(unit_prices: [:price, :effective_date, :_destroy])[:unit_prices]
    }
  end
end
```

Alternatively, if you don't want to override the constructor:

```ruby
class Product::Item::Save < Legatus::Directive
  attr_accessor :item

  props do
    {
      item:        { dig: [:item], permit: [:id, :name, :description, :partner_id, :status] },
      unit_prices: { dig: [:item, :unit_prices], map: permit([:price, :effective_date, :_destroy]) }
    }
  end
end
```

Wherein the value describes a series of method calls to be performed in sequence, that is:

```ruby
# item: { dig: [:item], permit: [:id, :name, :description, :partner_id, :status] }
# is equivalent to:

@props[:item] = params[:item].dig(:item).permit(:id, :name, :description, :partner_id, :status)

# The method `permit` for `unit_prices` in the above example actually returns a lambda function which will be pased to map. 
# unit_prices: { dig: [:item, :unit_prices], map: permit([:price, :effective_date, :_destroy]) }
# is equivalent to:

@props[:unit_prices] = params.dig(:item, :unit_prices).map &permit([:price, :effective_date, :_destroy])

```

The method `permit` can also handle permitting nested values, for example:

```ruby
props do
  {
    line_items: { 
      dig: [:order, :line_items], 
      map: permit(
        [:id, :item_id, :price, :quantity, :payments, :added_at, :start_date, :end_date], 
        payments: [:id, :amount, :paid_at, :status]
      )
    }
  }
end

# The above is equivalent to:
@props[:line_items] = params.dig(:order, :line_items).map do |li|
  li.permit(:id, :item_id, :price, :quantity, :payments, :added_at, :start_date, :end_date).tap do |whitelisted|
    whitelisted[:payments_attributes] = li.permit(payments: [:id, :amount, :paid_at, :status])[:payments]
  end
end if params[:order][:line_items].present?
```

The main advantage of using the class-level ``props`` declaration is that it will stop the chain of method invocations once the return value of one of the invocations returns nil (which is the case when the user leaves certain parameters blank). It uses ``Legatus::Chain`` to perform the method invocations.

### Clean

The second step is "cleaning" the extracted properties of the directive. This may include setting default or derived values as well as validations before attempting to retrieve or create `ActiveRecord` models. In `Legatus::Directive` the clean method is defined as:

```ruby
def clean
  self.reqs(self.props, self.props.keys)
end
```

Which simply means all properties declared in the previous step is required (i.e., the values must not return true when `.blank?` is called on them). To add a custom error, simply set a value using `@errors`:

```ruby
def clean
  @errors[:message] = 'Not authorized' if @user.is_guest?
end
```

Take note that adding a value to `@error` will cause `valid?` of the directive to return false. Which will halt the execution chain if `execute` is used in the directive because `execute` will call `valid?` before proceeding to the next step.

### Load

The third step is loading or initializing models or services that will be used to persist the changes for the directive. We can override it like so:

```ruby
def load
  @item = Product::Item.find_and_init(
    @props[:item].slice(:id),
    @props[:item].merge(unit_prices_attributes: @props[:unit_prices])
  )
end
```

In the above example, the method `find_and_init` is defined in `Legatus::Repository`. It simply uses find_by on the first parameter, instantiates a new one if none is found, and then sets the attributes of that model using the second attribute.

Alternatively, models can be declared using:

```ruby
class Product::Item::Save < Legatus::Directive
  attr_accessor :item

  model(:item) do |props|
    Product::Item.find_and_init(
      props[:item].slice(:id),
      props[:item].merge(unit_prices_attributes: props[:unit_prices])
    )
  end
end
```

Attributes declared using `attr_accessor` can be injected onto the lambda function passed to `model` so long as the parameter name in the lambda function is the same as the attribute. For example, using a more complex directive:

```ruby
class School::Student::Registration < Legatus::Directive

  attr_accessor :user, :university, 
                :graduate, :student, :enrollment

  props do |params|
    #...
  end
  
  model(:user) do |props|
    #...
  end

  model(:university) do |props|
    #...
  end

  # The attributes user and university is passed onto the lambda
  model(:graduate) do |props, user, university|
    Credential::Graduate.find_and_init(
      props[:graduate].merge(
        user:       user,
        university: university
      )
    )
  end
end
```

This is achived using the flexcon gem.

### Validate

The fourth step is the validation of the models. If you defined the models at the class level (e.g. `model(:item) { ... }`), by default, all models registered that way will be validated because the metadata on which attributes of the directive are models is available. On the other hand, if a custom load model was defined, you can also define a custom validate model:

```ruby
def validate
  if @item.invalid?
    @errors[key] ||= {}
    @errors[key].merge!(@item.errors)
  end
end
```

### Persist

The fifth and final step is persisting the changes to the database. You can define a custom `persist` method:

```ruby
def persist
  @item.save
end
```

Or define it at the class level:

```ruby
class Product::Item::Save < Legatus::Directive

  attr_accessor :item

  transaction do |uow, operation|
    uow.save operation.item
  end
end
```

The uow above is a ```Legatus::UnitOfWork``` which is useful for directives that persist multiple models. A unit of work will store all save operations as lambda functions and will only start persisting them when `commit` is called. This is useful for when there are additional logic that needs to be performed  in between saving models. Such that when `commit` is called, only persistence operations are performed. When a transaction is defined at the class level, the `commit` automatically after calling the block.

### All Together Now

The save order directive, using class-level definitions, would then look like:

```ruby
class Product::Item::Save < Legatus::Directive

  attr_accessor :item

  props do |params|
    {
      item:        { dig: [:item], permit: [:id, :name, :description, :partner_id, :status] },
      unit_prices: { dig: [:item, :unit_prices], map: permit([:price, :effective_date, :_destroy]) }
    }
  end

  model(:item) do |props|
    Product::Item.find_and_init(
      props[:item].slice(:id),
      props[:item].merge(unit_prices_attributes: props[:unit_prices])
    )
  end

  transaction do |uow, operation|
    uow.save operation.item
  end
end
```


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
