json.payload do
  json.array! @labels do |label|
    json.id label.id
    json.title label.title
    json.description label.description
    json.color label.color
    json.show_on_sidebar label.show_on_sidebar
    counts = @label_counts.fetch(label.title, [0, 0])
    json.contacts_count counts[1]
    json.conversations_count counts[0]
  end
end
