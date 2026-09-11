json.payload do
  json.array! @labels do |label|
    json.id label.id
    json.title label.title
    json.description label.description
    json.color label.color
    json.show_on_sidebar label.show_on_sidebar
    json.contacts_count label.contacts_count
    json.conversations_count label.conversations_count
  end
end
