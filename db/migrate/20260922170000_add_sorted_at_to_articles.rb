class AddSortedAtToArticles < ActiveRecord::Migration[8.1]
  def change
    # A stored generated column so feed fetches (insert_all, no callbacks) and
    # existing rows get the sort key for free. A plain column can lead a
    # composite index and be compared as a row value for keyset pagination.
    add_column :articles, :sorted_at, :virtual, type: :datetime,
      as: "COALESCE(published_at, created_at)", stored: true
    add_index :articles, [ :feed_id, :sorted_at, :id ], order: { sorted_at: :desc, id: :desc }
  end
end
