class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      # A standalone feed_id index is covered by the composite unique index below.
      t.references :feed, null: false, foreign_key: true, index: false
      # The entry's id in the feed (RSS guid / Atom id), falling back to its URL.
      t.string :guid, null: false
      t.string :url, null: false
      t.string :title, null: false
      t.datetime :published_at

      t.timestamps
    end

    # Fetching skips entries already stored, per feed (feeds are per user, ADR 0003).
    add_index :articles, [ :feed_id, :guid ], unique: true
  end
end
