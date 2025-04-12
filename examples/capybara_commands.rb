require_relative "capybara"

class CreateCapybara < Foobara::Command
  inputs Capybara.attributes_for_create
  result Capybara

  def execute
    create_capybara

    capybara
  end

  attr_accessor :capybara

  def create_capybara
    self.capybara = Capybara.create(inputs)
  end
end

class UpdateCapybara < Foobara::Command
  inputs Capybara.attributes_for_update
  result Capybara

  def execute
    load_capybara
    update_capybara

    capybara
  end

  attr_accessor :capybara

  def load_capybara
    self.capybara = Capybara.load(id)
  end

  def update_capybara
    capybara.update(inputs)
  end
end

class FindAllCapybaras < Foobara::Command
  result [Capybara]

  def execute
    find_all_capybaras
  end

  def find_all_capybaras
    Capybara.all
  end
end
