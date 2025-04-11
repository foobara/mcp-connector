require_relative "capybara_commands"

capybaras = FindAllCapybaras.run!

capybara_names = capybaras.map(&:name)

unless capybara_names.include?("Fumiko")
  CreateCapybara.run!(name: "Fumiko", year_of_birth: 2000)
end

unless capybara_names.include?("Barbara")
  CreateCapybara.run!(name: "Barbara", year_of_birth: 1999)
end

unless capybara_names.include?("Basil")
  CreateCapybara.run!(name: "Basil", year_of_birth: 2001)
end
