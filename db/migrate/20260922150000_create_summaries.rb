class CreateSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :summaries do |t|
      t.references :article, null: false, foreign_key: true, index: false
      t.string :language, null: false
      t.text :body
      t.string :state, null: false, default: "pending"
      # A reason code (see Summary::FAILURE_REASONS), turned into a message in the view.
      t.string :failure_reason
      t.timestamps
    end
    add_index :summaries, %i[article_id language], unique: true
  end
end
