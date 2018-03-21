# Rails Importer 

Rails Importer (XML, XLS, CSV)

## How to install

Add it to your **Gemfile**: 
```ruby
gem 'rails-importer'
```

Run the following command to install it:
```sh
$ bundle install
$ rails generate rails_importer:install
```

## Generators

You can generate importers `app/importers/example_importer.rb`

```sh
$ rails generate rails_importer:importer example
```

Generator will make a file with content like:

```ruby
class ExampleImporter < RailsImporter::Base

  importer do
    fields :name, :email, :age
    #or fields({:name => "Name", :email => "E-mail", :age => "Idade"})
    each_record do |record, params|
    
      MyModel.find_or_create_by(name: record[:name], email: record[:email], age: record[:age])
      
      return record # or return wherever
    end
  end
  
  # importer :simple do
  #   xml_structure :root, :row
  #   fields :name, :email, :age
  #   each_record do |record, params|
  #       ...
  #   end
  # end

end
```

### How to use

You can call `import` from **Importers** objects: 
**file param** must be an object that responds to `.path` method
```ruby
    file = params[:import][:file]
    records = ExampleImporter.import(file)
```

Or with context:
```ruby
    file = params[:import][:file]
    records = ExampleImporter.import(file, context: :simple)
```

Overwrite default fields (called in the block `importer do`):
```ruby
    file = params[:import][:file]
    records = ExampleImporter.import(file, fields: [:name, :email, :age])
```

With extra params:
```ruby
    file = params[:import][:file]
    records = ExampleImporter.import(file, {user: 'john@mail.com'})
```
Then inside each record you can get params:
```ruby
class ExampleImporter < RailsImporter::Base
  importer do
    # ...
    each_record do |record, params|
      # ...
      params[:user]
      # ...
    end
    # ...
  end
end
```

With full options:
```ruby
    file = params[:import][:file]
    records = ExampleImporter.import(file,
      context: :simple,
      fields: [:name, :email, :age],
      {user: 'john@mail.com', account: '1'})
```

To return imported values, you need to return values inside of `each_record`:
```ruby
class ExampleImporter < RailsImporter::Base
  importer do
    # ...
    each_record do |record, params|
      # ...
      u = Model.new(record)
      u.created_by = params[:user]
      ok = !!u.save
      return {record: u, success: ok}
    end
    # ...
  end
end
records = ExampleImporter.import(file, {user: 'john@mail.com'})
# [{record: ..., success: true}, {record: ..., success: false}]
```
