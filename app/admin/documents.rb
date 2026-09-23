ActiveAdmin.register Document do
  permit_params :name, :slug, :title, :body, :published
end
