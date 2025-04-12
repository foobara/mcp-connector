require_relative "capybara_commands"

capybaras = FindAllCapybaras.run!

capybara_names = capybaras.map(&:name)

unless capybara_names.include?("Fumiko")
  CreateCapybara.run!(name: "Fumiko", year_of_birth: 2020)
end

unless capybara_names.include?("Barbara")
  CreateCapybara.run!(name: "Barbara", year_of_birth: 2019)
end

unless capybara_names.include?("Basil")
  CreateCapybara.run!(name: "Basil", year_of_birth: 2021)
end
