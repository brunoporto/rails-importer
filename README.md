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
    each_record do |record, params|
      MyModel.find_or_create_by(name: record[:name], email: record[:email], age: record[:age])
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
```erb
    file = params[:import][:file]
    records = ExampleImporter.import(file, extra_param: 'Extra')
```

Or with context:

```erb
    file = params[:import][:file]
    records = ExampleImporter.import(file, context: :simple, extra_param: 'Extra')
```