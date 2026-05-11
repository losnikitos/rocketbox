class AddSlugToChapters < ActiveRecord::Migration[8.1]
  class Chapter < ActiveRecord::Base
    self.table_name = "chapters"
  end

  def up
    add_column :chapters, :slug, :string

    Chapter.reset_column_information
    Chapter.order(:book_id, :position, :id).find_each do |chapter|
      chapter.update_columns(slug: unique_slug_for(chapter))
    end

    change_column_null :chapters, :slug, false
    add_index :chapters, [:book_id, :slug], unique: true
  end

  def down
    remove_index :chapters, column: [:book_id, :slug]
    remove_column :chapters, :slug
  end

  private

    def unique_slug_for(chapter)
      base = chapter.title.to_s.parameterize
      base = "chapter-#{chapter.position}" if base.blank?
      slug = base
      suffix = 2

      while Chapter.where(book_id: chapter.book_id, slug: slug).exists?
        slug = "#{base}-#{suffix}"
        suffix += 1
      end

      slug
    end
end
