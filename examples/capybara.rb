require "foobara/local_files_crud_driver"

Foobara::Persistence.default_crud_driver = Foobara::LocalFilesCrudDriver.new

class Capybara < Foobara::Entity
  attributes do
    id :integer
    name :string, :required
    year_of_birth :integer, :required
  end

  primary_key :id
end
