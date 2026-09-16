class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      # A standalone user_id index is covered by the composite unique index below.
      t.references :user, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.string :url, null: false

      t.timestamps
    end

    # Feeds are owned per user (ADR 0003), so uniqueness is scoped to the user.
    add_index :feeds, [ :user_id, :url ], unique: true
  end
end
