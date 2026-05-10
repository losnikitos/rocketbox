# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :documents, :slug, unique: true

    reversible do |dir|
      dir.up do
        say_with_time "Creating draft documents" do
          Document.reset_column_information
          Document.create!(
            name: "Terms and Conditions",
            title: "Terms and Conditions",
            body: "# Draft\n\nAdd your terms and conditions here.",
            published: false
          )
          Document.create!(
            name: "Privacy Policy",
            title: "Privacy Policy",
            body: "# Draft\n\nAdd your privacy policy here.",
            published: false
          )
        end
      end

      dir.down do
        Document.where(slug: %w[terms-and-conditions privacy-policy]).delete_all
      end
    end
  end
end
